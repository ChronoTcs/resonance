import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as audio_meta;
import 'package:audio_metadata_reader/audio_metadata_reader.dart'
    show Mp3Metadata, VorbisMetadata, Mp4Metadata;
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../data/models/download_item.dart';
import '../data/datasources/downloader_bridge_datasource.dart';
import '../../../core/data/services/media_cache_service.dart';
import '../../../core/data/services/cache_manager.dart';
import '../../../core/application/services/permission_service.dart';
import '../../../../core/utils/path_utils.dart';
import '../../library/application/library_provider.dart';
import '../../library/data/models/media_item.dart';
import 'providers/download_settings_provider.dart';
import '../../settings/application/notification_provider.dart';
import '../../player/application/providers/audio_provider.dart';

/// Event emitted by DownloadService to update the UI State in DownloadNotifier.
class DownloadUpdate {
  final String id;
  final DownloadItem Function(DownloadItem) updater;
  DownloadUpdate(this.id, this.updater);
}

/// Orchestrator for the download system.
/// Handles Queueing, Concurrency, Metadata, and Platform-specific execution.
class DownloadService {
  final Ref _ref;
  final DownloaderBridgeDatasource _bridge = DownloaderBridgeDatasource();
  final _resolveCompleters = <String, Completer<String?>>{};

  final _updateController = StreamController<DownloadUpdate>.broadcast();
  Stream<DownloadUpdate> get updateStream => _updateController.stream;

  bool _isScheduling = false;
  bool _isRateLimited = false;
  DateTime? _rateLimitResetTime;

  DownloadService(this._ref) {
    if (!Platform.isAndroid) {
      _bridge.initialize();
      _bridge.bridgeEvents.listen(_handleBridgeEvent);
      _bridge.errorStream.listen((msg) => _emitGlobalError(msg));
    }

    // Auto-teardown
    _ref.onDispose(() {
      _bridge.dispose();
      _updateController.close();
    });
  }

  bool get isRateLimited {
    if (_isRateLimited && _rateLimitResetTime != null) {
      if (DateTime.now().isAfter(_rateLimitResetTime!)) {
        _isRateLimited = false;
        _rateLimitResetTime = null;
      }
    }
    return _isRateLimited;
  }

  void _emitUpdate(String id, DownloadItem Function(DownloadItem) updater) {
    if (!_updateController.isClosed) {
      _updateController.add(
        DownloadUpdate(id, (item) {
          final updated = updater(item);
          if (updated.status != item.status) {
            if (updated.status == DownloadStatus.done) {
              _ref
                  .read(notificationProvider.notifier)
                  .showNotification(
                    'Download Complete',
                    '${updated.displayTitle} has been downloaded successfully.',
                    target: 'target:download',
                  );
            } else if (updated.status == DownloadStatus.error) {
              _ref
                  .read(notificationProvider.notifier)
                  .showNotification(
                    'Download Failed',
                    'Failed to download ${updated.displayTitle}: ${updated.errorMessage ?? "Unknown error"}',
                    isError: true,
                    target: 'target:download',
                  );
            }
          }
          return updated;
        }),
      );
    }
  }

  void _emitGlobalError(String message) {
    debugPrint('[DownloadService] ERROR: $message');
  }

  // ── Queue Management ───────────────────────────────────────────────────────

  void cancelItem(String id) {
    _emitUpdate(id, (item) => item.copyWith(status: DownloadStatus.cancelled));
    if (!Platform.isAndroid) {
      _bridge.sendCommand({'action': 'cancel', 'id': id});
    }
  }

  Future<void> scheduleNext(List<DownloadItem> currentQueue) async {
    if (_isScheduling) return;
    _isScheduling = true;

    try {
      if (isRateLimited) {
        _emitGlobalError('Queue paused: IP Cooldown active.');
        return;
      }

      final active = currentQueue
          .where((i) => i.status == DownloadStatus.downloading)
          .length;
      final settingsValue = _ref.read(downloadSettingsProvider);
      final settings = settingsValue.asData?.value ?? const DownloadSettings();
      final maxConcurrent = settings.maxConcurrent;

      if (active >= maxConcurrent) return;

      final queued = currentQueue
          .where((i) => i.status == DownloadStatus.queued)
          .toList();
      if (queued.isEmpty) return;

      final toStart = queued.take(maxConcurrent - active);

      for (final item in toStart) {
        final cacheService = _ref.read(mediaCacheServiceProvider);
        final songId = item.id.contains('_') ? item.url : item.id;

        final cachedPath = await cacheService.getCachedAudioPath(songId);
        final isCached = cachedPath != null;
        final isCachingByDart = cacheService.isCaching(songId);

        if (isCached || isCachingByDart) {
          _startDirectDownloadFromCache(item);
          continue;
        }

        // JITTER: Random delay to mimic human behavior
        await Future.delayed(
          Duration(milliseconds: 500 + (item.hashCode % 1000)),
        );

        if (Platform.isAndroid) {
          _startAndroidDownload(item);
        } else {
          _startDownload(item);
        }
      }
    } finally {
      _isScheduling = false;
    }
  }

  // ── Platform Specific Handlers (Windows Bridge) ────────────────────────────

  Future<void> _startDownload(DownloadItem item) async {
    _emitUpdate(item.id, (i) => i.copyWith(status: DownloadStatus.downloading));

    final settings = await _ref.read(downloadSettingsProvider.future);
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';

    final musicPath = settings.musicOutputPath.isNotEmpty
        ? settings.musicOutputPath
        : '$home\\Music\\Resonance Downloads';
    final videoPath = settings.videoOutputPath.isNotEmpty
        ? settings.videoOutputPath
        : '$home\\Videos\\Resonance Downloads';
    final lyricsPath = settings.lyricsOutputPath.isNotEmpty
        ? settings.lyricsOutputPath
        : '$musicPath\\Lyrics';

    String sourceStr = _resolveSourceStr(item);
    final cacheManager = _ref.read(cacheManagerProvider);
    final localImagesDir = await cacheManager.getLocalImagesDir();

    _bridge.sendCommand({
      'action': 'download',
      'id': item.id,
      'url': item.url,
      'type': item.type == DownloadType.audio ? 'audio' : 'video',
      'source': sourceStr,
      'music_path': musicPath,
      'video_path': videoPath,
      'lyrics_path': lyricsPath,
      'images_path': localImagesDir.path,
      'ffmpeg_path': DownloaderBridgeDatasource.resolveFFmpegDir(),
      'quality': settings.audioQuality,
      'max_retries': settings.maxRetries,
      'socket_timeout': settings.connectionTimeout,
      'concurrent_fragments': settings.fragmentsPerDownload,
    });
  }

  void _handleBridgeEvent(Map<String, dynamic> evt) {
    final type = evt['type'] as String? ?? '';
    final id = evt['id'] as String? ?? '';
    if (id.isEmpty && type != 'ready') return;

    if (id.startsWith('resolve_') && _resolveCompleters.containsKey(id)) {
      final completer = _resolveCompleters.remove(id);
      if (type == 'resolved') {
        completer?.complete(evt['url'] as String?);
      } else {
        completer?.complete(null);
      }
      return;
    }

    switch (type) {
      case 'progress':
        _emitUpdate(
          id,
          (item) => item.copyWith(
            status: DownloadStatus.downloading,
            progress: (evt['percent'] as num?)?.toDouble() ?? item.progress,
            speed: evt['speed'] as String?,
            eta: (evt['eta'] as num?)?.toInt(),
          ),
        );
        break;
      case 'done':
        final outputPath = evt['path'] as String?;
        final title = evt['title'] as String?;
        final songId = evt['songId'] as String? ?? id;
        final artPath = evt['art_path'] as String?;

        DownloadItem? updatedItem;
        _emitUpdate(id, (item) {
          updatedItem = item.copyWith(
            status: DownloadStatus.done,
            progress: 100.0,
            resolvedTitle: title,
            outputPath: outputPath,
          );
          return updatedItem!;
        });
        if (outputPath != null && updatedItem != null) {
          _syncToLibraryWithTags(updatedItem!, songId, outputPath, artPath);
        }
        break;
      case 'lyrics':
        final status = evt['status'] as String? ?? 'unknown';
        final message = status == 'found'
            ? '🎵 Lyrics found and saved.'
            : (status == 'not_found'
                  ? '❌ Lyrics not found.'
                  : '⚠ Lyrics error: ${evt['message']}');
        _emitUpdate(id, (item) => item.copyWith(logs: [...item.logs, message]));
        break;
      case 'log':
        final msg = evt['message'] as String? ?? '';
        _emitUpdate(
          id,
          (item) => item.copyWith(
            status: DownloadStatus.downloading,
            statusMessage: msg,
            logs: [...item.logs, msg],
          ),
        );
        break;
      case 'error':
        final msg = evt['message'] as String? ?? 'Unknown error';
        _emitUpdate(
          id,
          (item) =>
              item.copyWith(status: DownloadStatus.error, errorMessage: msg),
        );
        break;
    }
  }

  // ── Cache Flow (Instant Copy) ──────────────────────────────────────────────

  Future<void> _startDirectDownloadFromCache(DownloadItem item) async {
    _emitUpdate(
      item.id,
      (i) => i.copyWith(
        status: DownloadStatus.downloading,
        statusMessage: 'Menemukan cache...',
      ),
    );

    final cacheService = _ref.read(mediaCacheServiceProvider);
    final songId = item.id.contains('_') ? item.url : item.id;

    final activeFuture = cacheService.getActiveDownload(songId);
    if (activeFuture != null) {
      _emitUpdate(
        item.id,
        (i) => i.copyWith(statusMessage: 'Waiting for prefetch...'),
      );
      await activeFuture;
    }

    final cachedAudio = await cacheService.getCachedAudioPath(songId);
    if (cachedAudio == null) {
      if (Platform.isAndroid) return _startAndroidDownload(item);
      return _startDownload(item);
    }

    _emitUpdate(
      item.id,
      (i) => i.copyWith(statusMessage: 'Copying from cache...'),
    );

    final settings = await _ref.read(downloadSettingsProvider.future);
    String downloadDir;
    if (item.type == DownloadType.audio) {
      downloadDir = settings.musicOutputPath.isNotEmpty
          ? settings.musicOutputPath
          : (Platform.isAndroid ? await PathUtils.getMusicDefault() : '');
    } else {
      downloadDir = settings.videoOutputPath.isNotEmpty
          ? settings.videoOutputPath
          : '';
    }

    if (downloadDir.isEmpty && !Platform.isAndroid) {
      final home =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      downloadDir = item.type == DownloadType.audio
          ? '$home\\Music\\Resonance Downloads'
          : '$home\\Videos\\Resonance Downloads';
    }

    final dir = Directory(downloadDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final cachedMedia = await cacheService.getCachedMetadata(songId);
    final videoId = cachedMedia?.id ?? (item.video?.id.value ?? songId);
    final String locId = PathUtils.generateLocId(videoId);
    final extension = p.extension(cachedAudio).isEmpty
        ? '.m4a'
        : p.extension(cachedAudio);
    final targetPath = p.join(downloadDir, '$locId$extension');

    try {
      if (await File(targetPath).exists()) {
        _emitUpdate(
          item.id,
          (i) => i.copyWith(
            status: DownloadStatus.done,
            statusMessage: 'Already in library.',
          ),
        );
        return;
      }

      await File(cachedAudio).copy(targetPath);

      // Lyrics copy
      final cachedLrc = await cacheService.getCachedLyricsPath(songId);
      if (cachedLrc != null) {
        final lrcDirBase = settings.lyricsOutputPath.isNotEmpty
            ? settings.lyricsOutputPath
            : (Platform.isAndroid
                  ? await PathUtils.getLyricsDefault()
                  : p.join(downloadDir, 'Lyrics'));
        final lrcDir = Directory(lrcDirBase);
        if (!await lrcDir.exists()) await lrcDir.create(recursive: true);
        await File(cachedLrc).copy(p.join(lrcDir.path, '$locId.lrc'));
      }

      // local art goes to local/images/, not cache/images/
      final imagesDir = await _ref
          .read(cacheManagerProvider)
          .getLocalImagesDir();
      final targetArtPath = p.join(imagesDir.path, 'art_$locId.jpg');
      Uint8List? artBytes;

      // Resolve clean title/artist from enriched metadata (avoids karaoke/channel name contamination)
      final rawTitle = cachedMedia?.title ?? item.displayTitle;
      final rawArtist =
          cachedMedia?.artist ?? item.video?.author ?? 'Unknown Artist';
      // same sanitization as _fetchEnhancedMetadata to prevent "ZZangKARAOKE" style iTunes mismatches
      final cleanArtist = rawArtist
          .replaceAll(
            RegExp(
              r'\s*-\s*topic$|\s*vevo$|\s*official$|\s*music$|\s*tv$',
              caseSensitive: false,
            ),
            '',
          )
          .trim()
          .split(',')
          .first
          .trim();

      // 1. Try iTunes high-res art first with sanitized artist (prevents karaoke cover bleed-through)
      bool itunesArtSuccess = false;
      try {
        final itunesRes = await HttpClient()
            .getUrl(
              Uri.parse(
                'https://itunes.apple.com/search?term=${Uri.encodeComponent("$rawTitle $cleanArtist")}&media=music&limit=1',
              ),
            )
            .then((req) => req.close());
        final itunesData = jsonDecode(
          await itunesRes.transform(utf8.decoder).join(),
        );
        if (itunesData['results']?.isNotEmpty == true) {
          final artworkUrl100 =
              itunesData['results'][0]['artworkUrl100'] as String?;
          if (artworkUrl100 != null) {
            final highResUrl = artworkUrl100.replaceAll(
              '100x100bb',
              '600x600bb',
            );
            final httpClient = http.Client();
            try {
              final response = await httpClient.get(Uri.parse(highResUrl));
              if (response.statusCode == 200) {
                final bytes = response.bodyBytes;
                await File(targetArtPath).writeAsBytes(bytes);
                artBytes = Uint8List.fromList(bytes);
                // Also overwrite stream/images/ cache so SMTC/Discord get correct art immediately
                await cacheService.cacheArtwork(
                  songId,
                  highResUrl,
                  forceOverwrite: true,
                );
                itunesArtSuccess = true;
              }
            } finally {
              httpClient.close();
            }
          }
        }
      } catch (_) {}

      // 2. Fallback to YouTube thumbnail if iTunes lookup failed
      if (!itunesArtSuccess) {
        final currentTrack = _ref.read(audioProvider).currentTrack;
        final httpArtUrl =
            (currentTrack?.id == videoId || currentTrack?.setVideoId == videoId)
            ? currentTrack?.thumbnailUrl
            : (cachedMedia?.thumbnailUrl ?? item.video?.thumbnails.highResUrl);

        if (httpArtUrl != null && httpArtUrl.startsWith('http')) {
          await cacheService.cacheArtwork(songId, httpArtUrl);
        }

        final artPath = await cacheService.getCachedArtPath(songId);
        if (artPath != null) {
          final artFile = File(artPath);
          if (await artFile.exists()) {
            await artFile.copy(targetArtPath);
            artBytes = await artFile.readAsBytes();
          }
        }
      }

      if (item.type == DownloadType.audio) {
        await _writeTags(
          targetPath,
          cachedMedia?.title ?? item.displayTitle,
          cachedMedia?.artist ?? 'Unknown Artist',
          cachedMedia?.album ?? 'Resonance Downloads',
          artBytes != null ? artBytes.toList() : [],
          songId,
        );
        _emitUpdate(
          item.id,
          (i) => i.copyWith(
            logs: [...i.logs, '🎵 Metadata embedded successfully.'],
          ),
        );
      }

      _emitUpdate(
        item.id,
        (i) => i.copyWith(
          status: DownloadStatus.done,
          progress: 100.0,
          outputPath: targetPath,
          resolvedTitle: cachedMedia?.title ?? item.displayTitle,
          statusMessage: 'Done (Instant copy from cache)',
          songId: locId,
        ),
      );

      _ref
          .read(libraryProvider.notifier)
          .addMediaItem(
            MediaItem(
              id: locId,
              setVideoId: songId,
              path: targetPath,
              title: cachedMedia?.title ?? item.displayTitle,
              artist: cachedMedia?.artist ?? 'Unknown Artist',
              album: cachedMedia?.album ?? 'Resonance Downloads',
              thumbnailUrl: targetArtPath,
              type: item.type == DownloadType.audio ? 'audio' : 'video',
            ),
          );
    } catch (e) {
      _emitUpdate(
        item.id,
        (i) => i.copyWith(
          status: DownloadStatus.error,
          errorMessage: 'Instant copy failed: $e',
        ),
      );
    }
  }

  // ── Android Native Download Logic ──────────────────────────────────────────

  Future<void> _startAndroidDownload(DownloadItem item) async {
    _emitUpdate(
      item.id,
      (i) => i.copyWith(
        status: DownloadStatus.downloading,
        statusMessage: 'Preparing...',
      ),
    );

    if (!await PermissionService.requestDownloadPermissions()) {
      _emitUpdate(
        item.id,
        (i) => i.copyWith(
          status: DownloadStatus.error,
          errorMessage: 'Permission denied. (Storage required)',
        ),
      );
      return;
    }

    final settings = await _ref.read(downloadSettingsProvider.future);
    final int maxAttempts = settings.maxRetries + 1;
    int attempt = 0;
    bool success = false;

    while (attempt < maxAttempts && !success) {
      attempt++;
      if (attempt > 1) {
        _emitUpdate(
          item.id,
          (i) =>
              i.copyWith(statusMessage: 'Retrying ($attempt/$maxAttempts)...'),
        );
        await Future.delayed(const Duration(seconds: 2));
      }

      final ytClient = yt.YoutubeExplode();
      try {
        _emitUpdate(
          item.id,
          (i) => i.copyWith(
            statusMessage: 'Fetching metadata...',
            logs: [...i.logs, '🌐 Connecting to YouTube API...'],
          ),
        );

        yt.Video video;
        if (item.video != null) {
          video = item.video!;
          _emitUpdate(
            item.id,
            (i) =>
                i.copyWith(logs: [...i.logs, '♻ Reusing existing metadata.']),
          );
        } else {
          try {
            if (item.url.contains('youtu.be') ||
                item.url.contains('youtube.com')) {
              video = await ytClient.videos
                  .get(item.url)
                  .timeout(Duration(seconds: settings.connectionTimeout));
            } else {
              final searchResult = await ytClient.search
                  .search(item.url)
                  .timeout(Duration(seconds: settings.connectionTimeout));
              if (searchResult.isEmpty) throw Exception('No results found');
              video = searchResult.first;
            }
          } catch (e) {
            _emitUpdate(
              item.id,
              (i) => i.copyWith(
                logs: [
                  ...i.logs,
                  '⚠ Fetch failed: $e. Retrying search fallback...',
                ],
              ),
            );
            final searchResult = await ytClient.search
                .search(item.url)
                .timeout(Duration(seconds: settings.connectionTimeout));
            if (searchResult.isEmpty) {
              throw Exception('Video not playable and search fallback failed.');
            }
            video = searchResult.first;
          }
        }

        _emitUpdate(
          item.id,
          (i) => i.copyWith(
            displayTitle: video.title,
            resolvedTitle: video.title,
            logs: [...i.logs, '📦 Metadata resolved: ${video.title}'],
          ),
        );

        final manifest = await ytClient.videos.streamsClient
            .getManifest(
              video.id,
              ytClients: [
                yt.YoutubeApiClient.androidVr,
                yt.YoutubeApiClient.ios,
              ],
            )
            .timeout(Duration(seconds: settings.connectionTimeout));

        yt.StreamInfo streamInfo;
        if (item.type == DownloadType.audio) {
          final audioStreams = manifest.audioOnly;
          final mp4Streams = audioStreams.where(
            (e) =>
                e.container.name.toLowerCase() == 'mp4' ||
                e.container.name.toLowerCase() == 'm4a',
          );
          streamInfo = mp4Streams.isNotEmpty
              ? mp4Streams.withHighestBitrate()
              : audioStreams.withHighestBitrate();
        } else {
          final muxed = manifest.muxed.toList();
          if (muxed.isEmpty) throw Exception('No muxed streams available.');
          muxed.sort(
            (a, b) => a.videoQuality.index.compareTo(b.videoQuality.index),
          );
          streamInfo = muxed.last;
        }

        String downloadDir = item.type == DownloadType.audio
            ? (settings.musicOutputPath.isNotEmpty
                  ? settings.musicOutputPath
                  : await PathUtils.getMusicDefault())
            : settings.videoOutputPath;
        final dir = Directory(downloadDir);
        if (!await dir.exists()) await dir.create(recursive: true);

        final extension = item.type == DownloadType.audio
            ? (streamInfo.container.name == 'mp4'
                  ? 'm4a'
                  : streamInfo.container.name)
            : streamInfo.container.name;
        final String locId = PathUtils.generateLocId(video.id.value);
        final filePath = p.join(downloadDir, '$locId.$extension');
        final file = File(filePath);
        _emitUpdate(
          item.id,
          (i) => i.copyWith(outputPath: filePath, songId: locId),
        );

        final output = file.openWrite();
        final stream = ytClient.videos.streamsClient.get(streamInfo);
        int downloaded = 0;
        final total = streamInfo.size.totalBytes;
        double lastUpdatePercent = 0.0;

        await for (final chunk in stream.timeout(
          Duration(seconds: settings.connectionTimeout),
        )) {
          output.add(chunk);
          downloaded += chunk.length;
          final percent = (downloaded / total) * 100;
          if (percent - lastUpdatePercent >= 1.0 || percent >= 99.9) {
            lastUpdatePercent = percent;
            _emitUpdate(
              item.id,
              (i) => i.copyWith(
                progress: percent,
                statusMessage: 'Downloading: ${percent.toStringAsFixed(1)}%',
              ),
            );
          }
        }
        await output.close();

        if (item.type == DownloadType.audio) {
          final metadata = await _fetchEnhancedMetadata(
            video,
            locId,
            settings,
            item.id,
          );
          final imageBytes = await _fetchThumbnail(
            metadata.trackTitle,
            metadata.trackArtist,
            video,
            item.id,
          );
          await _writeTags(
            filePath,
            metadata.trackTitle,
            metadata.trackArtist,
            metadata.albumName,
            imageBytes,
            video.id.value,
          );
          final localImagesDir = await _ref
              .read(cacheManagerProvider)
              .getLocalImagesDir();
          final targetArt = p.join(localImagesDir.path, 'art_$locId.jpg');
          if (imageBytes.isNotEmpty) {
            await File(targetArt).writeAsBytes(imageBytes);
          }
          _ref
              .read(libraryProvider.notifier)
              .addMediaItem(
                MediaItem(
                  id: locId,
                  path: filePath,
                  title: metadata.trackTitle,
                  artist: metadata.trackArtist,
                  album: metadata.albumName,
                  thumbnailUrl: targetArt,
                  type: 'audio',
                ),
              );
        } else {
          _ref
              .read(libraryProvider.notifier)
              .addMediaItem(
                MediaItem(
                  id: locId,
                  path: filePath,
                  title: video.title,
                  type: 'video',
                ),
              );
        }

        _emitUpdate(
          item.id,
          (i) => i.copyWith(
            status: DownloadStatus.done,
            progress: 100.0,
            outputPath: filePath,
            statusMessage: 'Download complete',
            logs: [...i.logs, '🏁 Finalizing... Success!'],
          ),
        );
        success = true;
      } catch (e) {
        if (_is429(e)) {
          _isRateLimited = true;
          _rateLimitResetTime = DateTime.now().add(const Duration(minutes: 15));
          _emitUpdate(
            item.id,
            (i) => i.copyWith(
              status: DownloadStatus.error,
              errorMessage: 'YouTube Rate Limited (429). Queue paused for 15m.',
              logs: [...i.logs, '🔴 $e'],
            ),
          );
          break;
        }
        if (attempt >= maxAttempts) {
          _emitUpdate(
            item.id,
            (i) => i.copyWith(
              status: DownloadStatus.error,
              errorMessage: e.toString(),
            ),
          );
        } else {
          _emitUpdate(
            item.id,
            (i) => i.copyWith(logs: [...i.logs, 'Attempt $attempt failed: $e']),
          );
        }
      } finally {
        ytClient.close();
      }
    }
  }

  // ── Helper Logic (Metadata extraction) ─────────────────────────────────────

  Future<({String trackTitle, String trackArtist, String albumName})>
  _fetchEnhancedMetadata(
    yt.Video video,
    String locId,
    DownloadSettings settings,
    String updateId,
  ) async {
    _emitUpdate(
      updateId,
      (i) => i.copyWith(
        statusMessage: 'Fetching rich metadata...',
        logs: [...i.logs, '🔍 Searching LRCLIB for enhanced metadata...'],
      ),
    );
    String albumName = 'Resonance Downloads';
    String trackTitle = video.title;
    String trackArtist = video.author;

    try {
      final match = RegExp(
        r"Album\s*:\s*(.*)",
        caseSensitive: false,
      ).firstMatch(video.description);
      if (match?.group(1) != null) {
        albumName = match!.group(1)!.trim();
        _emitUpdate(
          updateId,
          (i) => i.copyWith(
            logs: [...i.logs, '📝 Found album in description: $albumName'],
          ),
        );
      }
    } catch (_) {}

    try {
      String cleanTitle = video.title
          .replaceAll(
            RegExp(
              r'\(official.*?\)|\[official.*?\]|\(music video\)|\(lyric.*?\)|\[lyric.*?\]|\(audio\)|\(video\)|\[mv\]',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'vevo', caseSensitive: false), '')
          .trim();
      String cleanArtist = video.author
          .replaceAll(
            RegExp(
              r'\s*-\s*topic$|\s*vevo$|\s*official$|\s*music$|\s*tv$',
              caseSensitive: false,
            ),
            '',
          )
          .trim()
          .split(',')
          .first
          .trim();

      final searchStages = [
        {'q': '$cleanTitle $cleanArtist', 'label': 'Exact'},
        {'q': cleanTitle, 'label': 'Title-only'},
      ];
      bool metadataFound = false;

      for (final stage in searchStages) {
        if (metadataFound) break;
        final query = stage['q'];
        _emitUpdate(
          updateId,
          (i) => i.copyWith(
            logs: [...i.logs, '🔎 Lyrics [${stage['label']}]: "$query"'],
          ),
        );

        try {
          final lrcRes = await HttpClient()
              .getUrl(
                Uri.parse(
                  'https://lrclib.net/api/search?q=${Uri.encodeComponent(query!)}',
                ),
              )
              .then((req) => req.close());
          final responseBody = await lrcRes.transform(utf8.decoder).join();
          final List<dynamic> results = jsonDecode(responseBody);

          if (results.isNotEmpty) {
            Map<String, dynamic>? bestMatch;
            for (var res in results) {
              final apiArtist = res['artistName']?.toString().toLowerCase();
              if (stage['label'] == 'Exact' ||
                  (apiArtist != null &&
                      (apiArtist.contains(cleanArtist.toLowerCase()) ||
                          cleanArtist.toLowerCase().contains(apiArtist)))) {
                bestMatch = res;
                if (res['syncedLyrics'] != null) break;
              }
            }
            if (bestMatch != null) {
              albumName = bestMatch['albumName'] ?? albumName;
              trackTitle = bestMatch['trackName'] ?? trackTitle;
              trackArtist = bestMatch['artistName'] ?? trackArtist;
              metadataFound = true;
              final lyrics =
                  bestMatch['syncedLyrics'] ?? bestMatch['plainLyrics'];
              if (lyrics != null) {
                final lrcPath = p.join(
                  settings.lyricsOutputPath.isNotEmpty
                      ? settings.lyricsOutputPath
                      : await PathUtils.getLyricsDefault(),
                  '$locId.lrc',
                );
                final lrcFile = File(lrcPath);
                if (!await lrcFile.parent.exists()) {
                  await lrcFile.parent.create(recursive: true);
                }
                await lrcFile.writeAsString(lyrics.toString());
                _emitUpdate(
                  updateId,
                  (i) =>
                      i.copyWith(logs: [...i.logs, '✅ Lyrics found & saved.']),
                );
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Fallback: If albumName is still default, query iTunes API for official album title
    if (albumName == 'Resonance Downloads') {
      try {
        final itunesRes = await HttpClient()
            .getUrl(
              Uri.parse(
                'https://itunes.apple.com/search?term=${Uri.encodeComponent("$trackTitle $trackArtist")}&media=music&entity=song&limit=1',
              ),
            )
            .then((req) => req.close());
        final itunesData = jsonDecode(
          await itunesRes.transform(utf8.decoder).join(),
        );
        if (itunesData['results']?.isNotEmpty == true) {
          final collectionName = itunesData['results'][0]['collectionName']
              ?.toString();
          if (collectionName != null && collectionName.isNotEmpty) {
            albumName = collectionName;
            _emitUpdate(
              updateId,
              (i) => i.copyWith(
                logs: [...i.logs, '🎵 Found album from iTunes: $albumName'],
              ),
            );
          }
        }
      } catch (_) {}
    }

    return (
      trackTitle: trackTitle,
      trackArtist: trackArtist,
      albumName: albumName,
    );
  }

  Future<List<int>> _fetchThumbnail(
    String title,
    String artist,
    yt.Video video,
    String updateId,
  ) async {
    _emitUpdate(
      updateId,
      (i) => i.copyWith(
        statusMessage: 'Downloading cover art...',
        logs: [...i.logs, '🖼 Fetching high-resolution cover art...'],
      ),
    );
    try {
      String? artworkUrl;
      try {
        // Strip movie/show subtitle to broaden iTunes search (prevents karaoke over-match)
        final cleanTitle = title
            .replaceAll(
              RegExp(
                r'\s*\([^)]*(?:verse|movie|film|soundtrack|ost|part|vol\.|from the|spider|into|the)[^)]*\)',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        final itunesRes = await HttpClient()
            .getUrl(
              Uri.parse(
                'https://itunes.apple.com/search?term=${Uri.encodeComponent("$cleanTitle $artist")}&media=music&limit=5',
              ),
            )
            .then((req) => req.close());
        final itunesData = jsonDecode(
          await itunesRes.transform(utf8.decoder).join(),
        );
        final results = itunesData['results'] as List?;
        if (results != null) {
          for (final r in results) {
            final album = r['collectionName']?.toString().toLowerCase() ?? '';
            // skip karaoke/tribute/compilation art same as discord_rpc_service
            if ([
              'karaoke',
              'tribute',
              'instrumental',
              'singalong',
              'sing along',
              'cover',
              'megatunez',
              'zzang',
              'best pop vol',
              'best hits vol',
            ].any(album.contains)) {
              continue;
            }
            artworkUrl = r['artworkUrl100']?.toString().replaceAll(
              '100x100bb',
              '600x600bb',
            );
            break;
          }
        }
      } catch (_) {}

      artworkUrl ??= video.thumbnails.maxResUrl.isNotEmpty
          ? video.thumbnails.maxResUrl
          : video.thumbnails.standardResUrl;
      final response = await HttpClient()
          .getUrl(Uri.parse(artworkUrl))
          .then((req) => req.close());
      final bytes = await response.expand((chunk) => chunk).toList();
      _emitUpdate(
        updateId,
        (i) => i.copyWith(
          logs: [
            ...i.logs,
            '🎨 Cover art resolved (${(bytes.length / 1024).round()} KB)',
          ],
        ),
      );
      return bytes;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeTags(
    String path,
    String title,
    String artist,
    String album,
    List<int> artBytes,
    String videoId,
  ) async {
    final ext = p.extension(path).toLowerCase();
    // audio_metadata_reader corrupts MP4 atom offsets (stco/co64/moov) when writing to .m4a/.mp4.
    // Skip binary mutation — all metadata is stored in LibraryProvider + resonance_library.json.
    if (ext == '.m4a' || ext == '.mp4') {
      debugPrint(
        '[DownloadService] Skipping binary tag mutation for M4A/MP4 container to prevent atom table corruption.',
      );
      return;
    }
    try {
      final file = File(path);
      audio_meta.updateMetadata(file, (metadata) {
        metadata.setTitle(title);
        metadata.setArtist(artist);
        metadata.setAlbum(album);
        if (metadata is Mp3Metadata) {
          metadata.customMetadata['YT_ID'] = videoId;
        } else if (metadata is VorbisMetadata) {
          metadata.description.add('YT_ID:$videoId');
        } else if (metadata is Mp4Metadata) {
          // Store it in lyrics field since Mp4Metadata doesn't support custom comments
          metadata.lyrics = '${metadata.lyrics ?? ''}\nYT_ID:$videoId'.trim();
        }
        if (artBytes.isNotEmpty) {
          metadata.setPictures([
            audio_meta.Picture(
              Uint8List.fromList(artBytes),
              lookupMimeType(path) ?? 'image/jpeg',
              audio_meta.PictureType.coverFront,
            ),
          ]);
        }
      });
    } catch (_) {}
  }

  bool _is429(dynamic e) {
    final errStr = e.toString().toLowerCase();
    return errStr.contains('requestlimitexceeded') ||
        errStr.contains('ratelimit') ||
        errStr.contains('429');
  }

  String _resolveSourceStr(DownloadItem item) {
    switch (item.source) {
      case DownloadSource.ytmusic:
        return 'ytmusic';
      case DownloadSource.youtube:
        return 'youtube';
      case DownloadSource.auto:
        final uri = Uri.tryParse(item.url);
        if (uri?.host.contains('youtube.com') == true ||
            uri?.host.contains('youtu.be') == true) {
          return 'youtube';
        }
        if (item.url.startsWith('http')) return 'url';
        return 'ytmusic';
    }
  }

  Future<void> _syncToLibraryWithTags(
    DownloadItem item,
    String songId,
    String outputPath,
    String? artPath,
  ) async {
    String artist = 'Unknown Artist';
    String? album = 'Unknown Album';
    String title = item.resolvedTitle ?? item.displayTitle;
    if (item.type == DownloadType.audio) {
      try {
        final file = File(outputPath);
        if (file.existsSync()) {
          final tag = audio_meta.readMetadata(file, getImage: false);
          title = tag.title?.isNotEmpty == true ? tag.title! : title;
          artist = tag.artist ?? artist;
          album = tag.album ?? album;
        }
      } catch (_) {}
    }
    _ref
        .read(libraryProvider.notifier)
        .addMediaItem(
          MediaItem(
            id: songId,
            setVideoId: songId,
            path: outputPath,
            title: title,
            artist: artist,
            album: album,
            thumbnailUrl: artPath,
            type: item.type == DownloadType.audio ? 'audio' : 'video',
          ),
        );
  }

  Future<String?> resolveStreamUrl(String videoId) async {
    if (Platform.isAndroid) return null;
    final bridge = _bridge.resolveBridgeForOneShot();
    if (bridge == null) return null;
    debugPrint(
      '[DownloadService] resolveStreamUrl: spawning one-shot process for $videoId',
    );
    Process? process;
    try {
      process = await Process.start(
        bridge.exe,
        bridge.args,
        runInShell: Platform.isWindows,
        environment: Platform.isWindows
            ? DownloaderBridgeDatasource.buildCleanEnvironment()
            : null,
      );

      final payload =
          '${jsonEncode({'action': 'resolve_stream', 'videoId': videoId})}\n';
      process.stdin.write(payload);
      await process.stdin.flush();

      final stdoutCompleter = Completer<String>();
      final sb = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        sb.write(data);
        if (data.contains('"type": "resolved"') ||
            data.contains('"type": "error"')) {
          if (!stdoutCompleter.isCompleted) {
            stdoutCompleter.complete(sb.toString());
          }
        }
      });

      final stdout = await stdoutCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process?.kill();
          return sb.toString();
        },
      );

      debugPrint('[DownloadService] resolve stdout: $stdout');
      for (final line in stdout.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final evt = jsonDecode(trimmed) as Map<String, dynamic>;
          if (evt['type'] == 'resolved') return evt['url'] as String?;
          if (evt['type'] == 'error') {
            debugPrint(
              '[DownloadService] Python resolve error: ${evt['message']}',
            );
            return null;
          }
        } catch (_) {}
      }
      return null;
    } on TimeoutException {
      debugPrint('[DownloadService] resolveStreamUrl TIMEOUT for $videoId');
      return null;
    } catch (e) {
      debugPrint('[DownloadService] resolveStreamUrl exception: $e');
      return null;
    } finally {
      process?.kill();
    }
  }
}

final downloadServiceProvider = Provider<DownloadService>((ref) {
  // keepAlive prevents Riverpod from destroying Python process on rebuild
  ref.keepAlive();
  return DownloadService(ref);
});
