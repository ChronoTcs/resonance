import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'data_usage_service.dart';
import 'cache_manager.dart';
import 'storage_service.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stream_cache_tracker_service.dart';
import '../../../features/settings/application/maintenance_provider.dart';
import '../../utils/thumbnail_utils.dart';
import '../../application/services/network_connectivity_service.dart';
import 'package:flutter/painting.dart';
import '../../providers/cached_stream_music_provider.dart';

Future<int> _scanDirectoryBytesAsync(Directory dir) async {
  int total = 0;
  if (!await dir.exists()) return 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
  } catch (_) {}
  return total;
}

final mediaCacheServiceProvider = Provider<MediaCacheService>((ref) {
  final dataUsageService = ref.watch(dataUsageServiceProvider);
  final cacheManager = ref.watch(cacheManagerProvider);
  final trackerService = ref.watch(streamCacheTrackerServiceProvider);
  final service = MediaCacheService(
    ref,
    dataUsageService,
    cacheManager,
    trackerService,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

class MediaCacheService {
  final Ref _ref;
  final DataUsageService _dataUsageService;
  final CacheManager _cacheManager;
  final StreamCacheTrackerService _trackerService;
  final http.Client _client = http.Client(); // Persistent HTTP client
  Timer? _cleanupTimer;
  Timer? _invalidateDebounce;

  void _notifyCacheChanged() {
    _invalidateDebounce?.cancel();
    _invalidateDebounce = Timer(const Duration(milliseconds: 500), () {
      _ref.invalidate(cachedStreamMusicProvider);
    });
  }

  // ── High-Performance Storage Cache & Delta Accounting ──
  final Map<String, int> _cachedSizes = {};
  final Map<String, DateTime> _dirModTimes = {};
  bool _isSizesInitialized = false;

  void _initSizes() {
    if (_isSizesInitialized) return;
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final savedJson = prefs.getString('cached_storage_sizes');
      if (savedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedJson);
        decoded.forEach((key, value) {
          if (value is int) _cachedSizes[key] = value;
        });
      }
    } catch (_) {}
    _isSizesInitialized = true;
  }

  void _saveSizesSnapshot() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      prefs.setString('cached_storage_sizes', jsonEncode(_cachedSizes));
    } catch (_) {}
  }

  /// Real-time incremental delta accounting (+/- bytes)
  void notifyDelta(String category, int byteDelta) {
    _initSizes();
    final current = _cachedSizes[category] ?? 0;
    final updated = (current + byteDelta).clamp(0, 9223372036854775807);
    _cachedSizes[category] = updated;
    _saveSizesSnapshot();
  }

  /// Resets category size to 0
  void resetCategorySize(String category) {
    _initSizes();
    _cachedSizes[category] = 0;
    _saveSizesSnapshot();
  }

  MediaCacheService(
    this._ref,
    this._dataUsageService,
    this._cacheManager,
    this._trackerService,
  );

  void setCustomPath(String? path) {
    _cacheManager.setCustomPath(path);
  }

  void dispose() {
    _client.close(); // Close the client when the service is disposed
    for (final client in _activeClients.values) {
      try {
        client.close();
      } catch (_) {}
    }
    _activeClients.clear();
    _cleanupTimer?.cancel();
    _invalidateDebounce?.cancel();
  }

  String getSafeFilename(String id) {
    return _cacheManager.getSafeFilename(id);
  }

  final Map<String, Future<void>> _activeDownloads = {};
  final Map<String, http.Client> _activeClients = {};
  final Set<String> _cancelledDownloads = {};
  final Set<String> _activeArtworkDownloads = {};
  // cooldown map prevents retry deadlock on network flicker
  final Map<String, DateTime> _failedDownloads = {};
  static const _kFailureCooldown = Duration(seconds: 60);

  /// Cancels an in-flight background audio download for [songId] immediately.
  /// Aborts the underlying HTTP socket and cleans up any partial .tmp file.
  void cancelActiveDownload(String songId) {
    _cancelledDownloads.add(songId);
    final client = _activeClients.remove(songId);
    if (client != null) {
      debugPrint('[MediaCache] Aborting active background download for $songId');
      try {
        client.close();
      } catch (_) {}
    }
  }

  Future<String> getAudioPath(
    String songId,
    String streamUrl, {
    String? userAgent,
    Map<String, String>? headers,
  }) async {
    final dir = await _cacheManager.getStreamAudioDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));

    if (file.existsSync()) {
      debugPrint('[MediaCache] Cache hit for $songId');
      // Update tracker setiap kali file diakses
      _trackerService.updateLastPlayed(songId);
      return file.path;
    }

    // If currently being downloaded, return streamUrl immediately so the player streams instantly instead of blocking
    if (_activeDownloads.containsKey(songId)) {
      debugPrint(
        '[MediaCache] Existing prefetch in progress for $songId. Returning streamUrl to avoid blocking.',
      );
      return streamUrl;
    }

    // [Deadlock Guard] If this song recently failed, suppress retry and stream directly
    final failedAt = _failedDownloads[songId];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _kFailureCooldown) {
      debugPrint(
        '[MediaCache] [$songId] In failure cooldown. Streaming directly.',
      );
      return streamUrl;
    }
    _failedDownloads.remove(songId); // cooldown expired — clear it

    debugPrint(
      '[MediaCache] Cache miss for $songId. Starting background cache...',
    );
    final downloadFuture =
        _downloadAudioInBackground(
          songId,
          streamUrl,
          file.path,
          userAgent: userAgent,
          headers: headers,
        ).catchError((e) {
          debugPrint(
            '[MediaCache] Caught unhandled background failure for $songId: $e',
          );
        });
    _activeDownloads[songId] = downloadFuture;

    return streamUrl;
  }

  bool isCaching(String songId) => _activeDownloads.containsKey(songId);

  Future<void>? getActiveDownload(String songId) => _activeDownloads[songId];

  Future<String?> getCachedAudioPath(String songId) async {
    // [Race Guard] If a download is in-flight, never return the partial file
    if (_activeDownloads.containsKey(songId)) return null;

    final dir = await _cacheManager.getStreamAudioDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));

    // [Integrity Guard] Only return path if file is fully written (> 64 KB)
    if (file.existsSync() && file.lengthSync() > 64 * 1024) {
      return file.path;
    }
    return null;
  }

  Future<void> _downloadAudioInBackground(
    String songId,
    String url,
    String savePath, {
    String? userAgent,
    Map<String, String>? headers,
  }) async {
    // [Atomic Write] Write to .tmp first; rename to final only on success
    final tmpPath = '$savePath.tmp';
    final tmpFile = File(tmpPath);
    final finalFile = File(savePath);

    int attempts = 0;
    const maxAttempts = 3;
    int downloadedBytes = 0;

    if (tmpFile.existsSync()) {
      try {
        downloadedBytes = tmpFile.lengthSync();
      } catch (_) {
        downloadedBytes = 0;
      }
    }

    try {
      while (attempts < maxAttempts) {
        if (_cancelledDownloads.contains(songId)) {
          debugPrint('[MediaCache] Background cache cancelled for $songId (skipped)');
          _cleanupTmpFile(tmpFile);
          return;
        }

        attempts++;
        final client = http.Client();
        _activeClients[songId] = client;
        IOSink? sink;

        try {
          final request = http.Request('GET', Uri.parse(url));

          if (headers != null && headers.isNotEmpty) {
            request.headers.addAll(headers);
            if (downloadedBytes > 0) {
              request.headers['Range'] = 'bytes=$downloadedBytes-';
            }
          } else {
            final activeUA =
                userAgent ??
                (url.contains('c=ANDROID_VR')
                    ? 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1)'
                    : url.contains('c=ANDROID')
                    ? 'com.google.android.youtube/19.29.37 (Linux; U; Android 14; GB) gzip'
                    : url.contains('c=IOS')
                    ? 'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)'
                    : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36");

            final isMobileClient = activeUA.toLowerCase().contains('android') ||
                activeUA.toLowerCase().contains('ios') ||
                url.contains('c=ANDROID_VR') ||
                url.contains('c=ANDROID') ||
                url.contains('c=IOS');

            final Map<String, String> resolvedHeaders = {
              'User-Agent': activeUA,
              'Accept': '*/*',
              'Accept-Language': 'en-US,en;q=0.9',
              'Connection': 'keep-alive',
              if (downloadedBytes > 0)
                'Range': 'bytes=$downloadedBytes-'
              else if (!url.contains('c=ANDROID'))
                'Range': 'bytes=0-',
            };

            if (!isMobileClient) {
              final origin = url.contains('music.youtube.com')
                  ? 'https://music.youtube.com'
                  : 'https://www.youtube.com';
              resolvedHeaders.addAll({
                'Origin': origin,
                'Referer': '$origin/',
                'Sec-Fetch-Dest': 'audio',
                'Sec-Fetch-Mode': 'cors',
                'Sec-Fetch-Site': 'cross-site',
              });
            }

            request.headers.addAll(resolvedHeaders);
          }

          final response = await client
              .send(request)
              .timeout(const Duration(minutes: 5));

          if (response.statusCode == 200 || response.statusCode == 206) {
            final isAppend = response.statusCode == 206 && downloadedBytes > 0;
            if (!isAppend) {
              downloadedBytes = 0;
              sink = tmpFile.openWrite(mode: FileMode.write);
            } else {
              sink = tmpFile.openWrite(mode: FileMode.append);
            }

            await response.stream.forEach((chunk) {
              if (_cancelledDownloads.contains(songId)) {
                throw _CancelledDownloadException();
              }
              sink!.add(chunk);
              downloadedBytes += chunk.length;
            });

            await sink.flush();
            await sink.close();
            sink = null;

            // [Integrity Check] Only promote to final path if download is substantive
            if (downloadedBytes > 64 * 1024) {
              // Atomically rename .tmp -> .m4a
              await tmpFile.rename(savePath);

              _dataUsageService.addBytes(downloadedBytes);
              notifyDelta('stream_audio', downloadedBytes);
              debugPrint(
                '[MediaCache] Audio cached successfully for $songId ($downloadedBytes bytes)',
              );

              // Tandai sebagai 'biasa diputar' agar masuk siklus 30 hari
              _trackerService.updateLastPlayed(songId);

              _scheduleCleanup();
              _notifyCacheChanged();
              return;
            } else {
              // Suspiciously small — discard .tmp
              debugPrint(
                '[MediaCache] Download too small for $songId ($downloadedBytes bytes) — discarding',
              );
              _cleanupTmpFile(tmpFile);
              throw Exception('Download too small: $downloadedBytes bytes');
            }
          } else if (response.statusCode == 416) {
            // Range Not Satisfiable: bytes requested were beyond end of file
            if (downloadedBytes > 64 * 1024) {
              await tmpFile.rename(savePath);
              debugPrint(
                '[MediaCache] Range 416 received for $songId with $downloadedBytes bytes present. Treating as complete.',
              );
              _scheduleCleanup();
              _notifyCacheChanged();
              return;
            } else {
              _cleanupTmpFile(tmpFile);
              throw Exception('HTTP 416 Range Not Satisfiable for $songId');
            }
          } else {
            throw Exception(
              'Media Integrity Check failed: Server returned ${response.statusCode}',
            );
          }
        } on _CancelledDownloadException {
          debugPrint('[MediaCache] Background cache cancelled for $songId (skipped)');
          if (sink != null) {
            try {
              await sink.close();
            } catch (_) {}
          }
          _cleanupTmpFile(tmpFile);
          return;
        } catch (e) {
          if (sink != null) {
            try {
              await sink.close();
            } catch (_) {}
          }

          if (_cancelledDownloads.contains(songId)) {
            debugPrint('[MediaCache] Background cache cancelled for $songId (skipped)');
            _cleanupTmpFile(tmpFile);
            return;
          }

          if (tmpFile.existsSync()) {
            try {
              downloadedBytes = tmpFile.lengthSync();
            } catch (_) {}
          }

          if (attempts < maxAttempts) {
            debugPrint(
              '[MediaCache] Connection dropped for $songId at $downloadedBytes bytes: $e. Resuming via HTTP Range ($attempts/$maxAttempts)...',
            );
            await Future.delayed(const Duration(milliseconds: 300));
            continue;
          } else {
            rethrow;
          }
        } finally {
          try {
            client.close();
          } catch (_) {}
          _activeClients.remove(songId);
        }
      }
    } catch (e) {
      if (_cancelledDownloads.contains(songId)) {
        debugPrint('[MediaCache] Background cache cancelled for $songId (skipped)');
        _cleanupTmpFile(tmpFile);
        return;
      }
      _failedDownloads[songId] = DateTime.now();
      debugPrint('[MediaCache] Audio caching failed for $songId: $e');
      _cleanupTmpFile(tmpFile);

      // Also clean stale final file if it somehow got written
      if (finalFile.existsSync()) {
        try {
          await finalFile.delete();
          debugPrint(
            '[MediaCache] Cleaned up corrupted session for $songId',
          );
        } catch (_) {}
      }
      rethrow; // Propagate error back to repository to trigger escalation
    } finally {
      try {
        _activeClients.remove(songId);
        _activeDownloads.remove(songId);
        _cancelledDownloads.remove(songId);
      } catch (_) {}
    }
  }

  void _cleanupTmpFile(File tmpFile) {
    if (tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
        debugPrint('[MediaCache] Cleaned up .tmp file');
      } catch (_) {}
    }
  }

  Future<String?> getLyrics(
    String songId,
    Future<String?> Function() fetchLyrics,
  ) async {
    final dir = await _cacheManager.getStreamLyricsDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.lrc'));

    if (file.existsSync()) {
      debugPrint('[MediaCache] Lyrics Cache hit for $songId');
      return await file.readAsString();
    }

    try {
      final lyrics = await fetchLyrics();
      if (lyrics != null &&
          lyrics.isNotEmpty &&
          !lyrics.toLowerCase().contains('not found') &&
          lyrics.trim().isNotEmpty) {
        // Ensure directory exists just in case
        if (!dir.existsSync()) await dir.create(recursive: true);

        await file.writeAsString(lyrics);
        debugPrint('[MediaCache] Lyrics SAVED to cache: ${file.path}');
        _trackerService.updateLastPlayed(songId);
        return lyrics;
      }
    } catch (e) {
      debugPrint('[MediaCache] Lyrics fetch/cache error: $e');
    }
    return null;
  }

  Future<String?> getCachedLyricsPath(String songId) async {
    final dir = await _cacheManager.getStreamLyricsDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.lrc'));
    return file.existsSync() ? file.path : null;
  }

  Future<String?> cacheArtwork(String songId, String? url, {bool forceOverwrite = false}) async {
    if (url == null || !url.startsWith('http')) return null;
    // Skip download entirely if offline — no point queuing it
    if (!_ref.read(networkConnectivityProvider).isOnline) return null;
    final upgradedUrl = ThumbnailUtils.upgradeResolution(url);
    // in-flight guard prevents duplicate concurrent downloads unless forceOverwrite is requested
    if (!forceOverwrite && _activeArtworkDownloads.contains(songId)) return null;

    try {
      final dir = await _cacheManager.getStreamImagesDir();
      final safeId = getSafeFilename(songId);

      // Deteksi ekstensi dari URL atau default ke .jpg
      String ext = '.jpg';
      if (upgradedUrl.toLowerCase().contains('.webp')) ext = '.webp';
      if (upgradedUrl.toLowerCase().contains('.png')) ext = '.png';

      final file = File(p.join(dir.path, 'art_$safeId$ext'));

      if (file.existsSync() && !forceOverwrite) {
        return file.path;
      }

      _activeArtworkDownloads.add(songId);
      var response = await _client.get(Uri.parse(upgradedUrl));
      if (response.statusCode != 200) {
        final fallbackUrl = ThumbnailUtils.getFallbackResolution(upgradedUrl);
        if (fallbackUrl != null && fallbackUrl != upgradedUrl) {
          response = await _client.get(Uri.parse(fallbackUrl));
        }
      }
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        notifyDelta('stream_images', response.bodyBytes.length);
        debugPrint('[MediaCache] Artwork cached safely: ${file.path}');

        // Also sync to local/images/ ONLY if this track already has a local download copy
        final localDir = await _cacheManager.getLocalImagesDir();
        final localFile = File(p.join(localDir.path, 'art_$safeId.jpg'));
        if (localFile.existsSync()) {
          try {
            await localFile.writeAsBytes(response.bodyBytes);
            notifyDelta('local_images', response.bodyBytes.length);
          } catch (_) {}
        }

        return file.path;
      }
    } catch (e) {
      debugPrint('[MediaCache] Artwork caching error: $e');
    } finally {
      _activeArtworkDownloads.remove(songId);
    }
    return null;
  }

  Future<void> saveArtToCache(String songId, Uint8List bytes) async {
    try {
      final dir = await _cacheManager.getStreamImagesDir();
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, 'art_$safeId.jpg'));
      if (!file.existsSync()) {
        await file.writeAsBytes(bytes);
        notifyDelta('stream_images', bytes.length);
        _trackerService.updateLastPlayed(songId);
        _scheduleCleanup();
      }
    } catch (e) {
      debugPrint('[MediaCache] Art caching error: $e');
    }
  }

  Future<String?> getCachedArtPath(String songId) async {
    try {
      final streamDir = await _cacheManager.getStreamImagesDir();
      final safeId = getSafeFilename(songId);
      for (final ext in ['.jpg', '.webp', '.png']) {
        final streamFile = File(p.join(streamDir.path, 'art_$safeId$ext'));
        if (streamFile.existsSync()) return streamFile.path;
      }

      // Fallback: check local/images/ for downloaded songs
      final localDir = await _cacheManager.getLocalImagesDir();
      for (final ext in ['.jpg', '.webp', '.png']) {
        final localFile = File(p.join(localDir.path, 'art_$safeId$ext'));
        if (localFile.existsSync()) return localFile.path;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveMetadata(String songId, MediaItem item) async {
    try {
      final dir = await _cacheManager.getMetadataDir();
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, '$safeId.json'));

      if (await file.exists()) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified).inHours < 1) return;
      }

      final cleanItem = (item.isStreaming && item.path.startsWith('http'))
          ? item.copyWith(path: songId)
          : item;
      final map = cleanItem.toJson(includeArt: false);
      // Use locked write
      await _cacheManager.synchronizedWrite(file, jsonEncode(map));
      _scheduleCleanup();
      _notifyCacheChanged();
    } catch (e) {
      debugPrint('[MediaCache] Metadata caching error: $e');
    }
  }

  /// Bypasses the 1-hour freshness guard when iTunes enrichment provides a
  /// better [album] or [thumbnailUrl] than what the sidecar JSON already has.
  /// only writes when enriched fields differ from stored values.
  Future<void> saveMetadataForced(String songId, MediaItem item) async {
    try {
      final dir = await _cacheManager.getMetadataDir();
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, '$safeId.json'));

      final cleanItem = (item.isStreaming && item.path.startsWith('http'))
          ? item.copyWith(path: songId)
          : item;

      // Read existing sidecar to check if enriched fields are actually new.
      if (await file.exists()) {
        try {
          final existing = MediaItem.fromJson(jsonDecode(await file.readAsString()));
          final isBadArtist = existing.artist == null ||
              existing.artist!.isEmpty ||
              existing.artist == 'Lagu' ||
              existing.artist == 'Song' ||
              existing.artist == 'Unknown Artist' ||
              existing.artist == 'Unknown';
          final hasGoodIncomingArtist = item.artist != null &&
              item.artist!.isNotEmpty &&
              item.artist != 'Lagu' &&
              item.artist != 'Song' &&
              item.artist != 'Unknown Artist' &&
              item.artist != 'Unknown';
          final artistEnriched = isBadArtist && hasGoodIncomingArtist;

          final albumEnriched = (existing.album == null || existing.album!.isEmpty || existing.album == 'Unknown Album') &&
              item.album != null && item.album!.isNotEmpty && item.album != 'Unknown Album';
          final artEnriched = (existing.thumbnailUrl == null || existing.thumbnailUrl!.isEmpty) &&
              item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty;
          if (!albumEnriched && !artEnriched && !artistEnriched) return; // nothing new to write
        } catch (_) {
          // corrupt sidecar — fall through and overwrite
        }
      }

      await _cacheManager.synchronizedWrite(file, jsonEncode(cleanItem.toJson(includeArt: false)));
      debugPrint('[MediaCache] Forced sidecar update for $songId (album/art enriched)');
      _notifyCacheChanged();
    } catch (e) {
      debugPrint('[MediaCache] Metadata forced-save error: $e');
    }
  }

  Future<MediaItem?> getCachedMetadata(String songId) async {
    try {
      final dir = await _cacheManager.getMetadataDir();
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, '$safeId.json'));
      if (!file.existsSync()) return null;
      final json = jsonDecode(await file.readAsString());
      return MediaItem.fromJson(json);
    } catch (e) {
      debugPrint('[MediaCache] Metadata retrieval error: $e');
      return null;
    }
  }

  Future<void> removeFromCache(String songId) async {
    try {
      final safeId = getSafeFilename(songId);

      final audioDir = await _cacheManager.getStreamAudioDir();
      final lyricsDir = await _cacheManager.getStreamLyricsDir();
      final imagesDir = await _cacheManager.getStreamImagesDir();
      final metaDir = await _cacheManager.getMetadataDir();

      final filesToDelete = [
        File(p.join(audioDir.path, '$safeId.m4a')),
        File(p.join(lyricsDir.path, '$safeId.lrc')),
        File(p.join(metaDir.path, '$safeId.json')),
        File(p.join(imagesDir.path, 'art_$safeId.jpg')),
        File(p.join(imagesDir.path, 'art_$safeId.png')),
        File(p.join(imagesDir.path, 'art_$safeId.webp')),
      ];

      for (final file in filesToDelete) {
        if (await file.exists()) {
          // SAFETY CHECK: Ensure we are only deleting within 'stream' or 'metadata' cache subfolders
          final normalizedPath = file.path.replaceAll('\\', '/');
          final isSafePath =
              normalizedPath.contains('/stream/') ||
              normalizedPath.contains('/cache/');

          if (isSafePath) {
            try {
              int len = 0;
              try {
                len = await file.length();
              } catch (_) {}
              await file.delete();
              if (normalizedPath.contains('/stream/audio/')) {
                notifyDelta('stream_audio', -len);
              } else if (normalizedPath.contains('/stream/lyrics/')) {
                notifyDelta('stream_lyrics', -len);
              } else if (normalizedPath.contains('/stream/images/')) {
                notifyDelta('stream_images', -len);
              } else if (normalizedPath.contains('/cache/metadata/')) {
                notifyDelta('metadata', -len);
              }
              debugPrint(
                '[MediaCache] Cache removal SUCCESS: ${p.basename(file.path)}',
              );
            } catch (e) {
              debugPrint(
                '[MediaCache] File removal postponed (locked by player): ${p.basename(file.path)}',
              );
            }
          } else {
            debugPrint(
              '[MediaCache] [CRITICAL] Blocked deletion of non-cache file: ${file.path}',
            );
          }
        }
      }
      _notifyCacheChanged();
    } catch (e) {
      debugPrint('[MediaCache] Cache removal error for $songId: $e');
    }
  }

  // ---------------- Cache Management (Granular Fast Scanning) ----------------

  Future<int> _getDirSizeFast(String category, Directory dir, {bool force = false}) async {
    if (!await dir.exists()) {
      _cachedSizes[category] = 0;
      return 0;
    }

    try {
      final stat = await dir.stat();
      final lastKnownMod = _dirModTimes[category];

      // O(1) Instant Cache Hit: Return cached size if directory modtime is unchanged and not forced
      if (!force && _cachedSizes.containsKey(category) && lastKnownMod != null && stat.modified.isAtSameMomentAs(lastKnownMod)) {
        return _cachedSizes[category]!;
      }

      // Re-scan dirty folder asynchronously (non-blocking, zero isolate overhead)
      final total = await _scanDirectoryBytesAsync(dir);
      _cachedSizes[category] = total;
      _dirModTimes[category] = stat.modified;
      _saveSizesSnapshot();
      return total;
    } catch (e) {
      debugPrint('[MediaCache] Error calculating size for ${dir.path}: $e');
      return _cachedSizes[category] ?? 0;
    }
  }

  Future<Map<String, int>> getDetailedCacheSizes({bool force = false}) async {
    _initSizes();

    final categories = <String, Future<Directory>>{
      'local_music': _cacheManager.getLocalMusicDir(),
      'local_lyrics': _cacheManager.getLocalLyricsDir(),
      'local_images': _cacheManager.getLocalImagesDir(),
      'metadata': _cacheManager.getMetadataDir(),
      'translate': _cacheManager.getTranslateDir(),
      'stream_audio': _cacheManager.getStreamAudioDir(),
      'stream_images': _cacheManager.getStreamImagesDir(),
      'stream_lyrics': _cacheManager.getStreamLyricsDir(),
    };

    final Map<String, int> sizes = {};
    for (final entry in categories.entries) {
      final dir = await entry.value;
      sizes[entry.key] = await _getDirSizeFast(entry.key, dir, force: force);
    }

    return sizes;
  }

  Future<String> getCacheSize({bool force = false}) async {
    try {
      final detailed = await getDetailedCacheSizes(force: force);
      final totalSize = detailed.values.fold(0, (sum, val) => sum + val);

      if (totalSize < 1024) return '$totalSize B';
      if (totalSize < 1024 * 1024) {
        return '${(totalSize / 1024).toStringAsFixed(2)} KB';
      }
      if (totalSize < 1024 * 1024 * 1024) {
        return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (e) {
      return '0 B';
    }
  }

  Future<void> clearCategory(String category) async {
    try {
      Directory? dir;
      switch (category) {
        case 'local_music':
          dir = await _cacheManager.getLocalMusicDir();
          break;
        case 'local_lyrics':
          dir = await _cacheManager.getLocalLyricsDir();
          break;
        case 'local_images':
          dir = await _cacheManager.getLocalImagesDir();
          break;
        case 'metadata':
          dir = await _cacheManager.getMetadataDir();
          break;
        case 'translate':
          dir = await _cacheManager.getTranslateDir();
          break;
        case 'images':
          dir = await _cacheManager.getStreamImagesDir();
          break;
        case 'stream_audio':
          dir = await _cacheManager.getStreamAudioDir();
          break;
        case 'stream_images':
          dir = await _cacheManager.getStreamImagesDir();
          break;
        case 'stream_lyrics':
          dir = await _cacheManager.getStreamLyricsDir();
          break;
        case 'all':
          await clearCache();
          return;
      }

      if (dir != null && await dir.exists()) {
        try {
          final List<FileSystemEntity> entities = await dir.list(followLinks: false).toList();
          for (final entity in entities) {
            if (entity is File) {
              try {
                await entity.delete();
              } catch (_) {
                // Silently skip files locked by audio player engine or OS
              }
            }
          }
        } catch (_) {}
        resetCategorySize(category);
        debugPrint('[MediaCache] Cleared category $category');
      }

      // Evict Flutter's memory image cache so deleted artwork doesn't cause decoding crashes
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('[MediaCache] Clear category error: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      // Clear all stream + system cache dirs; local/ is user data, not auto-cleared here
      final dirs = [
        await _cacheManager.getStreamAudioDir(),
        await _cacheManager.getStreamImagesDir(),
        await _cacheManager.getStreamLyricsDir(),
        await _cacheManager.getMetadataDir(),
        await _cacheManager.getTranslateDir(),
      ];

      for (var dir in dirs) {
        if (!dir.existsSync()) continue;
        try {
          final List<FileSystemEntity> entities = await dir.list(followLinks: false).toList();
          for (final entity in entities) {
            if (entity is File) {
              try {
                await entity.delete();
              } catch (_) {
                // Silently skip in-use/locked files
              }
            }
          }
        } catch (_) {}
      }
      resetCategorySize('stream_audio');
      resetCategorySize('stream_images');
      resetCategorySize('stream_lyrics');
      resetCategorySize('metadata');
      resetCategorySize('translate');
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('[MediaCache] FULL CACHE CLEARED');
    } catch (e) {
      debugPrint('[MediaCache] Clear full cache error: $e');
    }
  }

  void _scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(seconds: 5), () {
      final limitGb = _ref.read(streamCacheLimitGbProvider);
      final secondaryDays = _ref.read(secondaryCacheRetentionDaysProvider);
      final limitMb = limitGb * 1024;

      enforceCacheLimit(limitMb);
      _cacheManager.cleanupTemporaryStreams(maxAgeDays: secondaryDays);
      _cleanupOrphanTmpFiles(); // [Atomic Write] Clean stale .tmp files
    });
  }

  /// Purges orphaned `.tmp` download files older than 1 hour.
  /// These are left behind if the app crashed mid-download.
  Future<void> _cleanupOrphanTmpFiles() async {
    try {
      final dir = await _cacheManager.getStreamAudioDir();
      if (!dir.existsSync()) return;
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          final stat = entity.statSync();
          if (stat.modified.isBefore(cutoff)) {
            try {
              await entity.delete();
              debugPrint('[MediaCache] Purged orphan .tmp: ${entity.path}');
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaCache] Orphan .tmp cleanup error: $e');
    }
  }

  Future<void> enforceCacheLimit(int limitMb) async {
    // Load playlist-pinned track IDs so they are never evicted by the dynamic eraser.
    Set<String> pinnedIds = const {};
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final raw = prefs.getString('pinned_stream_ids');
      if (raw != null) {
        // These are already safe filenames (written by PlaylistNotifier._saveState).
        pinnedIds = Set<String>.from(jsonDecode(raw) as List);
      }
    } catch (_) {}
    await _cacheManager.enforceStreamAudioLimit(limitMb, pinnedIds: pinnedIds);
  }
}

class _CancelledDownloadException implements Exception {}
