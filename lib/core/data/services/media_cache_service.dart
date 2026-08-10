import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'data_usage_service.dart';
import 'cache_manager.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stream_cache_tracker_service.dart';
import '../../../features/settings/application/maintenance_provider.dart';
import '../../../features/explore/data/repositories/youtube_stream_repository.dart';
import '../../utils/thumbnail_utils.dart';

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
    _cleanupTimer?.cancel();
  }

  String getSafeFilename(String id) {
    return _cacheManager.getSafeFilename(id);
  }

  final Map<String, Future<void>> _activeDownloads = {};
  final Set<String> _activeArtworkDownloads = {};
  // cooldown map prevents retry deadlock on network flicker
  final Map<String, DateTime> _failedDownloads = {};
  static const _kFailureCooldown = Duration(seconds: 60);

  Future<String> getAudioPath(
    String songId,
    String streamUrl, {
    String? userAgent,
  }) async {
    final dir = await _cacheManager.getStreamAudioDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));

    if (file.existsSync()) {
      debugPrint('MediaCacheService: Cache hit for $songId');
      // Update tracker setiap kali file diakses
      _trackerService.updateLastPlayed(songId);
      return file.path;
    }

    // If currently being downloaded, return streamUrl immediately so the player streams instantly instead of blocking
    if (_activeDownloads.containsKey(songId)) {
      debugPrint(
        'MediaCacheService: Existing prefetch in progress for $songId. Returning streamUrl to avoid blocking.',
      );
      return streamUrl;
    }

    // [Deadlock Guard] If this song recently failed, suppress retry and stream directly
    final failedAt = _failedDownloads[songId];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _kFailureCooldown) {
      debugPrint(
        'MediaCacheService: [$songId] In failure cooldown. Streaming directly.',
      );
      return streamUrl;
    }
    _failedDownloads.remove(songId); // cooldown expired — clear it

    debugPrint(
      'MediaCacheService: Cache miss for $songId. Starting background cache...',
    );
    final downloadFuture =
        _downloadAudioInBackground(
          songId,
          streamUrl,
          file.path,
          userAgent: userAgent,
        ).catchError((e) {
          debugPrint(
            'MediaCacheService: Caught unhandled background failure for $songId: $e',
          );
        });
    _activeDownloads[songId] = downloadFuture;

    return streamUrl;
  }

  bool isCaching(String songId) => _activeDownloads.containsKey(songId);

  Future<void>? getActiveDownload(String songId) => _activeDownloads[songId];

  Future<String?> getCachedAudioPath(String songId) async {
    final dir = await _cacheManager.getStreamAudioDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));
    return file.existsSync() ? file.path : null;
  }

  Future<void> _downloadAudioInBackground(
    String songId,
    String url,
    String savePath, {
    String? userAgent,
  }) async {
    final file = File(savePath);
    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(url));

      final activeUA =
          userAgent ??
          (url.contains('c=ANDROID_VR')
              ? 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip'
              : url.contains('c=IOS')
              ? 'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)'
              : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36");

      final isAndroid = activeUA.toLowerCase().contains('android');

      final Map<String, String> resolvedHeaders = {
        'User-Agent': activeUA,
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
        'Range': 'bytes=0-',
      };

      if (!isAndroid) {
        resolvedHeaders.addAll({
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
          'Sec-Fetch-Dest': 'audio',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'cross-site',
        });
      }

      request.headers.addAll(resolvedHeaders);

      final response = await _client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode == 200 || response.statusCode == 206) {
        sink = file.openWrite();
        int downloadedBytes = 0;

        await response.stream.forEach((chunk) {
          sink!.add(chunk);
          downloadedBytes += chunk.length;
        });

        await sink.flush();
        await sink.close();
        sink = null;

        _dataUsageService.addBytes(downloadedBytes);
        debugPrint(
          'MediaCacheService: Audio cached successfully for $songId ($downloadedBytes bytes)',
        );

        // Tandai sebagai 'biasa diputar' agar masuk siklus 30 hari
        _trackerService.updateLastPlayed(songId);

        _scheduleCleanup();
      } else if (response.statusCode == 403) {
        // HTTP 403: Stream URL expired or signature rejected by specific CDN node.
        // Force-resolve a fresh stream URL directly via YoutubeStreamRepository to avoid circular provider loop.
        debugPrint(
          'MediaCacheService: [403 Retry] Stream URL expired for $songId. Resolving fresh URL via repo...',
        );
        final freshUrl = await _ref
            .read(youtubeStreamRepositoryProvider)
            .getStreamUrl(songId);
        if (freshUrl != null &&
            freshUrl != url &&
            freshUrl.startsWith('http')) {
          return await _downloadAudioInBackground(
            songId,
            freshUrl,
            savePath,
            userAgent: userAgent,
          );
        }
        throw Exception(
          'Media Integrity Check failed: Server returned 403 after retry',
        );
      } else {
        throw Exception(
          'Media Integrity Check failed: Server returned ${response.statusCode}',
        );
      }
    } catch (e) {
      _activeDownloads.remove(songId);
      // [Deadlock Guard] Record failure time to suppress retry spam
      _failedDownloads[songId] = DateTime.now();

      debugPrint('MediaCacheService: Audio caching failed for $songId: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }

      if (file.existsSync()) {
        try {
          await file.delete();
          debugPrint(
            'MediaCacheService: Cleaned up corrupted session for $songId',
          );
        } catch (_) {}
      }
      rethrow; // Propagate error back to repository to trigger escalation
    } finally {
      // Double check removal to prevent any deadlock
      _activeDownloads.remove(songId);
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
      debugPrint('MediaCacheService: Lyrics Cache hit for $songId');
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
        debugPrint('MediaCacheService: Lyrics SAVED to cache: ${file.path}');
        _trackerService.updateLastPlayed(songId);
        return lyrics;
      }
    } catch (e) {
      debugPrint('MediaCacheService: Lyrics fetch/cache error: $e');
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
      final response = await _client.get(Uri.parse(upgradedUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('MediaCacheService: Artwork cached safely: ${file.path}');

        // Also sync to local/images/ if this track has a local download copy
        final localDir = await _cacheManager.getLocalImagesDir();
        final localFile = File(p.join(localDir.path, 'art_$safeId.jpg'));
        if (localFile.existsSync() || forceOverwrite) {
          try {
            await localFile.writeAsBytes(response.bodyBytes);
          } catch (_) {}
        }

        return file.path;
      }
    } catch (e) {
      debugPrint('MediaCacheService: Artwork caching error: $e');
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
        _trackerService.updateLastPlayed(songId);
        _scheduleCleanup();
      }
    } catch (e) {
      debugPrint('Art caching error: $e');
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

      final map = item.toJson(includeArt: false);
      // Use locked write
      await _cacheManager.synchronizedWrite(file, jsonEncode(map));
      _scheduleCleanup();
    } catch (e) {
      debugPrint('Metadata caching error: $e');
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

      // Read existing sidecar to check if enriched fields are actually new.
      if (await file.exists()) {
        try {
          final existing = MediaItem.fromJson(jsonDecode(await file.readAsString()));
          final albumEnriched = (existing.album == null || existing.album!.isEmpty || existing.album == 'Unknown Album') &&
              item.album != null && item.album!.isNotEmpty && item.album != 'Unknown Album';
          final artEnriched = (existing.thumbnailUrl == null || existing.thumbnailUrl!.isEmpty) &&
              item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty;
          if (!albumEnriched && !artEnriched) return; // nothing new to write
        } catch (_) {
          // corrupt sidecar — fall through and overwrite
        }
      }

      await _cacheManager.synchronizedWrite(file, jsonEncode(item.toJson(includeArt: false)));
      debugPrint('[MediaCache] Forced sidecar update for $songId (album/art enriched)');
    } catch (e) {
      debugPrint('Metadata forced-save error: $e');
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
      debugPrint('Metadata retrieval error: $e');
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
              await file.delete();
              debugPrint(
                'MediaCacheService: Cache removal SUCCESS: ${p.basename(file.path)}',
              );
            } catch (e) {
              debugPrint(
                'MediaCacheService: File removal postponed (locked by player): ${p.basename(file.path)}',
              );
            }
          } else {
            debugPrint(
              'MediaCacheService: [CRITICAL] Blocked deletion of non-cache file: ${file.path}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Cache removal error for $songId: $e');
    }
  }

  // ---------------- Cache Management (Granular) ----------------

  Future<int> _getDirSize(Directory dir) async {
    int total = 0;
    if (!await dir.exists()) return 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (e) {
      debugPrint(
        'MediaCacheService: Error calculating size for ${dir.path}: $e',
      );
    }
    return total;
  }

  Future<Map<String, int>> getDetailedCacheSizes() async {
    final Map<String, int> sizes = {};

    // Local (downloaded) folders
    sizes['local_music'] = await _getDirSize(
      await _cacheManager.getLocalMusicDir(),
    );
    sizes['local_lyrics'] = await _getDirSize(
      await _cacheManager.getLocalLyricsDir(),
    );
    sizes['local_images'] = await _getDirSize(
      await _cacheManager.getLocalImagesDir(),
    );

    // Core system cache folders
    sizes['metadata'] = await _getDirSize(await _cacheManager.getMetadataDir());
    sizes['translate'] = await _getDirSize(
      await _cacheManager.getTranslateDir(),
    );

    // Stream sub-folders
    sizes['stream_audio'] = await _getDirSize(
      await _cacheManager.getStreamAudioDir(),
    );
    sizes['stream_images'] = await _getDirSize(
      await _cacheManager.getStreamImagesDir(),
    );
    sizes['stream_lyrics'] = await _getDirSize(
      await _cacheManager.getStreamLyricsDir(),
    );

    return sizes;
  }

  Future<String> getCacheSize() async {
    try {
      final detailed = await getDetailedCacheSizes();
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
        final List<FileSystemEntity> entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
        debugPrint('MediaCacheService: Cleared category $category');
      }
    } catch (e) {
      debugPrint('MediaCacheService: Clear category error: $e');
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
        final List<FileSystemEntity> entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
      debugPrint('MediaCacheService: FULL CACHE CLEARED');
    } catch (e) {
      debugPrint('Album art RPC cache/fetch error: $e');
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
    });
  }

  Future<void> enforceCacheLimit(int limitMb) async {
    await _cacheManager.enforceStreamAudioLimit(limitMb);
  }
}
