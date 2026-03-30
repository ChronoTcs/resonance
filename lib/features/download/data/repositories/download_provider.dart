import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/download/data/models/download_item.dart';
import 'package:resonance_app/features/download/data/repositories/download_settings_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:permission_handler/permission_handler.dart';
import 'package:audiotags/audiotags.dart' as tags;
import 'package:path/path.dart' as p;
import 'package:resonance_app/core/utils/path_utils.dart';
import 'package:resonance_app/core/services/media_cache_service.dart';
import 'package:resonance_app/features/library/application/library_provider.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/core/services/cache_manager.dart';

// ─── Public provider ────────────────────────────────────────────────────────
final downloadProvider = NotifierProvider<DownloadNotifier, List<DownloadItem>>(
  DownloadNotifier.new,
);


// ─── Notifier ────────────────────────────────────────────────────────────────
class DownloadNotifier extends Notifier<List<DownloadItem>> {
  // ── Bridge executable resolution ──────────────────────────────────────────
  //
  // Lookup order (first match wins):
  //  1. Production: resonance_downloader.exe next to our own .exe
  //     → Created by PyInstaller, copied here by CMakeLists install rule.
  //  2. Dev (PyInstaller already run): .exe in downloader/dist/
  //  3. Dev (Python available): .py script alongside a local resonance_downloader.py
  //
  // Returns a tuple: (executable, arguments)
  static Directory? _walkUpToProjectRoot(Directory start) {
    var dir = start;
    for (var i = 0; i < 10; i++) {
      if (File('${dir.path}\\pubspec.yaml').existsSync()) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static ({String exe, List<String> args}) _resolveBridge() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 1) Production — .exe built by PyInstaller lives next to our .exe
    final prodExe = '$exeDir\\resonance_downloader.exe';
    if (File(prodExe).existsSync()) {
      return (exe: prodExe, args: []);
    }

    // 2 & 3) Dev — find project root by walking up from the exe dir OR
    //         from Directory.current (which is the project root during `flutter run`)
    final projectRoot =
        _walkUpToProjectRoot(File(Platform.resolvedExecutable).parent) ??
        _walkUpToProjectRoot(Directory.current);

    if (projectRoot != null) {
      // The downloader/ folder sits next to resonance_app/ (i.e., projectRoot.parent)
      final downloaderRoot = projectRoot.path;

      // 2) Raw Python script — PREFERRED for active development (zero-setup)
      final devPy = '$downloaderRoot\\python_engine\\resonance_downloader.py';
      if (File(devPy).existsSync()) {
        return (exe: 'python', args: [devPy]);
      }

      // 3) PyInstaller .exe already built — Fallback if script is missing
      final devExe =
          '$downloaderRoot\\python_engine\\dist\\resonance_downloader.exe';
      if (File(devExe).existsSync()) {
        return (exe: devExe, args: []);
      }
    }

    // Absolute fallback — will fail gracefully in _launchBridge
    return (exe: 'resonance_downloader.exe', args: []);
  }

  Process? _process;
  StreamSubscription? _stdoutSub;
  bool _bridgeReady = false;
  final _pendingCommands = <String>[];
  bool _isRateLimited = false;
  bool _isScheduling = false;
  DateTime? _rateLimitResetTime;

  bool get isRateLimited {
    if (_isRateLimited && _rateLimitResetTime != null) {
      if (DateTime.now().isAfter(_rateLimitResetTime!)) {
        _isRateLimited = false;
        _rateLimitResetTime = null;
      }
    }
    return _isRateLimited;
  }

  int get _maxConcurrent {
    final s = ref.read(downloadSettingsProvider).value;
    return s?.maxConcurrent ?? 2;
  }

  @override
  List<DownloadItem> build() {
    ref.onDispose(_teardown);
    if (!Platform.isAndroid) {
      _launchBridge();
    }
    return [];
  }

  // ── Bridge lifecycle ───────────────────────────────────────────────────────

  Future<void> _launchBridge() async {
    final bridge = _resolveBridge();
    try {
      _process = await Process.start(
        bridge.exe,
        bridge.args,
        runInShell: bridge.exe == 'python',
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleEvent);

      _process!.stderr.transform(utf8.decoder).listen((line) {
        if (line.contains('MISSING_DEP')) {
          _emitGlobalError('Python dependency missing: $line');
        }
      });
    } catch (e) {
      final isPython = bridge.exe == 'python';
      _emitGlobalError(
        'Could not start download bridge (${bridge.exe}): $e\n\n'
        '${isPython ? "Ensure Python is installed and in your PATH.\n" : ""}'
        'Try running:  python build_downloader.py  from the resonance_app/ folder to rebuild the bridge.',
      );
    }
  }

  void _teardown() {
    _stdoutSub?.cancel();
    _sendRaw('{"action":"quit"}');
    _process?.kill();
    _process = null;
    _bridgeReady = false;
  }

  // ── Event handling ─────────────────────────────────────────────────────────

  void _handleEvent(String line) {
    if (line.isEmpty) return;
    Map<String, dynamic> evt;
    try {
      evt = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = evt['type'] as String? ?? '';
    if (type == 'ready') {
      _bridgeReady = true;
      for (final cmd in _pendingCommands) {
        _sendRaw(cmd);
      }
      _pendingCommands.clear();
      return;
    }

    final id = evt['id'] as String? ?? '';

    switch (type) {
      case 'progress':
        _updateItem(
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

        _updateItem(
          id,
          (item) {
            final updated = item.copyWith(
              status: DownloadStatus.done,
              progress: 100.0,
              resolvedTitle: title,
              outputPath: outputPath,
            );
            // Instant Sync with Library with rich ID3 parsing
            if (outputPath != null) {
              _syncToLibraryWithTags(updated, songId, outputPath, artPath);
            }
            return updated;
          },
        );
        // Kick off next queued download
        _scheduleNext();
        break;
      case 'lyrics':
        final status = evt['status'] as String? ?? 'unknown';
        final message = status == 'found'
            ? '🎵 Lyrics found and saved.'
            : (status == 'not_found'
                  ? '❌ Lyrics not found.'
                  : '⚠ Lyrics error: ${evt['message']}');
        _updateItem(id, (item) => item.copyWith(logs: [...item.logs, message]));
        break;
      case 'log':
        final msg = evt['message'] as String? ?? '';
        _updateItem(
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
        if (id.startsWith('dl_')) { // Just a safety check, or remove the if-else if redundant
          _updateItem(
            id,
            (item) => item.copyWith(
              status: DownloadStatus.error,
              errorMessage: msg,
            ),
          );
        }
        _scheduleNext();
        break;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Add one or many URLs/queries to the queue.
  void addToQueue(
    List<String> urls, {
    DownloadType type = DownloadType.audio,
    DownloadSource source = DownloadSource.ytmusic,
    yt.Video? video, // Optional metadata passthrough
  }) {
    final newItems = urls
        .map(
          (url) => DownloadItem(
            id: video?.id.value ?? '${DateTime.now().microsecondsSinceEpoch}_${url.hashCode}',
            url: url,
            displayTitle: video?.title ?? url,
            type: type,
            source: source,
            video: video,
          ),
        )
        .toList();
    state = [...state, ...newItems];
    _scheduleNext();
  }

  void cancelItem(String id) {
    _updateItem(id, (item) => item.copyWith(status: DownloadStatus.cancelled));
    // We can't easily kill a single thread inside the bridge; mark as cancelled
    // and skip it in scheduleNext
  }

  void clearCompleted() {
    state = state
        .where(
          (i) =>
              i.status != DownloadStatus.done &&
              i.status != DownloadStatus.error &&
              i.status != DownloadStatus.cancelled,
        )
        .toList();
  }

  // ── Scheduling ─────────────────────────────────────────────────────────────

  void _scheduleNext() async {
    if (_isScheduling) return;
    _isScheduling = true;

    try {
      if (isRateLimited) {
        _emitGlobalError('Queue paused: IP Cooldown active.');
        return;
      }

      final active = state
          .where((i) => i.status == DownloadStatus.downloading)
          .length;
      if (active >= _maxConcurrent) return;

      final queued = state
          .where((i) => i.status == DownloadStatus.queued)
          .toList();
      
      if (queued.isEmpty) return;

      final toStart = queued.take(_maxConcurrent - active);

      for (final item in toStart) {
        final cacheService = ref.read(mediaCacheServiceProvider);
        final songId = item.id.contains('_') ? item.url : item.id;
        
        // --- Concurrency & Platform Optimization ---
        final cachedPath = await cacheService.getCachedAudioPath(songId);
        final isCached = cachedPath != null;
        final isCachingByDart = cacheService.isCaching(songId);

        // Scenario 1: File is already 100% on disk (Universal fast-path)
        if (isCached) {
          _startDirectDownloadFromCache(item);
          continue;
        }

        // Scenario 2: Android Caching Logic 
        // On Android, we wait for the Dart prefetch because Android doesn't have Python script.
        if (Platform.isAndroid && isCachingByDart) {
            _startDirectDownloadFromCache(item);
            continue;
        }

        // Scenario 3: Regular Download Flow
        // JITTER: Random delay of 1-1.5 seconds to mimic human behavior
        await Future.delayed(Duration(milliseconds: 500 + (item.hashCode % 1000)));
        
        if (Platform.isAndroid) {
          _startAndroidDownload(item);
        } else {
          // Windows strictly uses the script downloader bridge
          _startDownload(item);
        }
      }
    } finally {
      _isScheduling = false;
    }
  }

  Future<void> _startDirectDownloadFromCache(DownloadItem item) async {
    _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.downloading, statusMessage: 'Discovering cache...'));
    
    final cacheService = ref.read(mediaCacheServiceProvider);
    final songId = item.id.contains('_') ? item.url : item.id;

    // Wait if still caching
    final activeFuture = cacheService.getActiveDownload(songId);
    if (activeFuture != null) {
      _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Waiting for prefetch to finish...'));
      await activeFuture;
    }

    final cachedAudio = await cacheService.getCachedAudioPath(songId);
    if (cachedAudio == null) {
      if (Platform.isAndroid) {
        return _startAndroidDownload(item);
      } else {
        return _startDownload(item);
      }
    }

    _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Copying from cache...'));

    final settings = await ref.read(downloadSettingsProvider.future);
    String downloadDir;
    if (item.type == DownloadType.audio) {
      downloadDir = settings.musicOutputPath.isNotEmpty 
          ? settings.musicOutputPath 
          : (Platform.isAndroid ? await PathUtils.getMusicDefault() : '');
    } else {
      downloadDir = settings.videoOutputPath.isNotEmpty 
          ? settings.videoOutputPath 
          : (Platform.isAndroid ? await PathUtils.getVideoDefault() : '');
    }

    if (downloadDir.isEmpty && !Platform.isAndroid) {
       final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
       downloadDir = item.type == DownloadType.audio ? '$home\\Music\\Resonance Downloads' : '$home\\Videos\\Resonance Downloads';
    }

    final dir = Directory(downloadDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    // GET UNIFIED ID & METADATA
    final cachedMedia = await cacheService.getCachedMetadata(songId);
    final videoId = cachedMedia?.id ?? (item.video?.id.value ?? songId);
    
    final extension = p.extension(cachedAudio).isEmpty ? '.m4a' : p.extension(cachedAudio);
    final fileName = '$videoId$extension';
    final targetPath = p.join(downloadDir, fileName);

    try {
      if (await File(targetPath).exists()) {
         _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.done, statusMessage: 'Already in library.'));
         return;
      }

      await File(cachedAudio).copy(targetPath);
      
      // Copy lyrics if exist
      final cachedLrc = await cacheService.getCachedLyricsPath(songId);
      if (cachedLrc != null) {
        final lrcDir = Directory(settings.lyricsOutputPath.isNotEmpty 
            ? settings.lyricsOutputPath 
            : (Platform.isAndroid ? await PathUtils.getLyricsDefault() : p.join(downloadDir, 'Lyrics')));
        if (!await lrcDir.exists()) await lrcDir.create(recursive: true);
        await File(cachedLrc).copy(p.join(lrcDir.path, '$videoId.lrc'));
      }

      // 4. SIDE CARS: Save .jpg for Resonance standards directly to images cache pool
      try {
        final imagesDir = await ref.read(cacheManagerProvider).getImagesDir();
        
        final targetArtPath = p.join(imagesDir.path, 'art_$videoId.jpg');

        // Write art sidecar (copy from cache)
        final artPath = await cacheService.getCachedArtPath(songId);
        if (artPath != null) {
           await File(artPath).copy(targetArtPath);
        }
        
      } catch (e) {
          debugPrint('Promotion: Sidecar error: $e');
      }

      _updateItem(item.id, (i) => i.copyWith(
        status: DownloadStatus.done,
        progress: 100.0,
        outputPath: targetPath,
        resolvedTitle: cachedMedia?.title ?? item.displayTitle,
        statusMessage: 'Instant Download (from cache)',
      ));

      // Instant Sync with Library
      final imagesDir = await ref.read(cacheManagerProvider).getImagesDir();
      ref.read(libraryProvider.notifier).addMediaItem(MediaItem(
        id: videoId,
        path: targetPath,
        title: cachedMedia?.title ?? item.displayTitle,
        artist: cachedMedia?.artist ?? 'Unknown Artist',
        album: cachedMedia?.album ?? 'Resonance Downloads',
        thumbnailUrl: p.join(imagesDir.path, 'art_$videoId.jpg'),
        type: item.type == DownloadType.audio ? 'audio' : 'video',
      ));
      
    } catch (e) {
      _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.error, errorMessage: 'Direct download failed: $e'));
    }
    
    _scheduleNext();
  }

  Future<void> _startDownload(DownloadItem item) async {
    _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.downloading));

    // Wait until settings are loaded to guarantee customized paths are respected
    final settings = await ref.read(downloadSettingsProvider.future);

    // If settings haven't loaded yet, we can still proceed using the defaults.
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final musicPath = (settings.musicOutputPath.isNotEmpty == true)
        ? settings.musicOutputPath
        : '$home\\Music\\Resonance Downloads';
    final videoPath = (settings.videoOutputPath.isNotEmpty == true)
        ? settings.videoOutputPath
        : '$home\\Videos\\Resonance Downloads';
    // Lyrics path defaults to a sub-folder inside the music path
    final lyricsPath = (settings.lyricsOutputPath.isNotEmpty == true)
        ? settings.lyricsOutputPath
        : '$musicPath\\Lyrics';

    String sourceStr;
    switch (item.source) {
      case DownloadSource.ytmusic:
        sourceStr = 'ytmusic';
        break;
      case DownloadSource.youtube:
        sourceStr = 'youtube';
        break;
      case DownloadSource.auto:
        sourceStr = item.url.startsWith('http') ? 'url' : 'ytmusic';
        break;
    }

    final cacheManager = ref.read(cacheManagerProvider);
    final imagesDir = await cacheManager.getImagesDir();

    final cmd = jsonEncode({
      'action': 'download',
      'id': item.id,
      'url': item.url,
      'type': item.type == DownloadType.audio ? 'audio' : 'video',
      'source': sourceStr,
      'music_path': musicPath,
      'video_path': videoPath,
      'lyrics_path': lyricsPath,
      'images_path': imagesDir.path,
      'quality': settings.audioQuality,
      'max_retries': settings.maxRetries,
      'socket_timeout': settings.connectionTimeout,
      'concurrent_fragments': settings.fragmentsPerDownload,
    });

    _sendCommand(cmd);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _syncToLibraryWithTags(DownloadItem item, String songId, String outputPath, String? artPath) async {
    String artist = 'Unknown Artist';
    String? album = 'Unknown Album';
    String title = item.resolvedTitle ?? item.displayTitle;

    if (item.type == DownloadType.audio) {
      try {
        final tag = await tags.AudioTags.read(outputPath);
        if (tag != null) {
          title = (tag.title != null && tag.title!.isNotEmpty) ? tag.title! : title;
          artist = tag.trackArtist ?? tag.albumArtist ?? artist;
          album = tag.album ?? album;
        }
      } catch (e) {
        debugPrint('Failed to read ID3 tags for sync: $e');
      }
    }

    ref.read(libraryProvider.notifier).addMediaItem(MediaItem(
      id: songId,
      path: outputPath,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: artPath,
      type: item.type == DownloadType.audio ? 'audio' : 'video',
    ));
  }

  void _sendCommand(String jsonCmd) {
    if (!_bridgeReady) {
      _pendingCommands.add(jsonCmd);
    } else {
      _sendRaw(jsonCmd);
    }
  }

  void _sendRaw(String line) {
    try {
      _process?.stdin.writeln(line);
    } catch (_) {}
  }

  void _updateItem(String id, DownloadItem Function(DownloadItem) updater) {
    state = [
      for (final item in state)
        if (item.id == id) updater(item) else item,
    ];
  }

  // ── Android Native Download ───────────────────────────────────────────────

  Future<void> _startAndroidDownload(DownloadItem item) async {
    _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.downloading, statusMessage: 'Preparing...'));

    // 1. Permissions (Must check before starting)
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      
      // Untuk Android 11+ (API 30+), kita wajib memiliki Manage External Storage 
      // agar bisa membuat folder Resonance di root (/storage/emulated/0/).
      if (sdkInt >= 30) {
        var manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) {
            _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.error, errorMessage: 'Permission denied. (Manage External Storage required)'));
            return;
          }
        }
      } else {
        // Untuk Android 10 ke bawah
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.error, errorMessage: 'Permission denied. (Storage required)'));
            return;
          }
        }
      }
    }

    final settings = await ref.read(downloadSettingsProvider.future);
    final int maxAttempts = settings.maxRetries + 1;
    int attempt = 0;
    bool success = false;

    while (attempt < maxAttempts && !success) {
      attempt++;
      if (attempt > 1) {
        _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Retrying ($attempt/$maxAttempts)...'));
        await Future.delayed(const Duration(seconds: 2));
      }

      final ytClient = yt.YoutubeExplode();
      try {
        _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Fetching metadata...', logs: [...i.logs, '🌐 Connecting to YouTube API...']));
        
        yt.Video video;
        if (item.video != null) {
          // METADATA PASSTHROUGH: Recycle existing video object to avoid API hits
          video = item.video!;
          _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '♻ Reusing existing metadata.']));
        } else {
          try {
            if (item.url.contains('youtu.be') || item.url.contains('youtube.com')) {
               video = await ytClient.videos.get(item.url).timeout(Duration(seconds: settings.connectionTimeout));
            } else {
               final searchResult = await ytClient.search.search(item.url).timeout(Duration(seconds: settings.connectionTimeout));
               if (searchResult.isEmpty) throw Exception('No results found');
               video = searchResult.first;
            }
          } catch (e) {
            _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '⚠ Fetch failed: $e. Retrying search fallback...']));
            final searchResult = await ytClient.search.search(item.url).timeout(Duration(seconds: settings.connectionTimeout));
            if (searchResult.isEmpty) throw Exception('Video not playable and search fallback failed.');
            video = searchResult.first;
          }
        }
        
        _updateItem(item.id, (i) => i.copyWith(
          displayTitle: video.title, 
          resolvedTitle: video.title,
          logs: [...i.logs, '📦 Metadata resolved: ${video.title}']
        ));

        _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Loading streams...', logs: [...i.logs, '📡 Resolving stream manifests...']));
        final manifest = await ytClient.videos.streamsClient.getManifest(
          video.id,
          ytClients: [yt.YoutubeApiClient.androidVr, yt.YoutubeApiClient.ios],
        ).timeout(Duration(seconds: settings.connectionTimeout));
        
        yt.StreamInfo streamInfo;
        if (item.type == DownloadType.audio) {
          final audioStreams = manifest.audioOnly;
          final mp4Streams = audioStreams.where((e) => 
              e.container.name.toLowerCase() == 'mp4' || 
              e.container.name.toLowerCase() == 'm4a');
          
          streamInfo = mp4Streams.isNotEmpty 
              ? mp4Streams.withHighestBitrate() 
              : audioStreams.withHighestBitrate();
        } else {
          final muxed = manifest.muxed.toList();
          if (muxed.isEmpty) throw Exception('No muxed streams available.');
          muxed.sort((a, b) => a.videoQuality.index.compareTo(b.videoQuality.index));
          streamInfo = muxed.last;
        }

        _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '🔗 Stream selected: ${streamInfo.codec.mimeType} (${streamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)']));

        String downloadDir;
        if (item.type == DownloadType.audio) {
          downloadDir = settings.musicOutputPath.isNotEmpty 
              ? settings.musicOutputPath 
              : await PathUtils.getMusicDefault();
        } else {
          downloadDir = settings.videoOutputPath.isNotEmpty 
              ? settings.videoOutputPath 
              : await PathUtils.getVideoDefault();
        }

        final dir = Directory(downloadDir);
        if (!await dir.exists()) await dir.create(recursive: true);

        final extension = item.type == DownloadType.audio 
            ? (streamInfo.container.name == 'mp4' ? 'm4a' : streamInfo.container.name)
            : streamInfo.container.name;
            
        // UNIFIED ID: Use loc_ hashed Video ID to align with python structure
        final String videoId = video.id.value;
        final String locId = PathUtils.generateLocId(videoId);
        final fileName = '$locId.$extension';
        final filePath = p.join(downloadDir, fileName);
        final file = File(filePath);
        _updateItem(item.id, (i) => i.copyWith(outputPath: filePath, songId: locId));

        final output = file.openWrite();
        final stream = ytClient.videos.streamsClient.get(streamInfo);
        
        int downloaded = 0;
        final total = streamInfo.size.totalBytes;
        double lastUpdatePercent = 0.0;

        await for (final chunk in stream.timeout(Duration(seconds: settings.connectionTimeout))) {
          output.add(chunk);
          downloaded += chunk.length;
          final percent = (downloaded / total) * 100;
          
          // THROTTLE: Only update UI if progress moves by at least 1% or finished
          if (percent - lastUpdatePercent >= 1.0 || percent >= 99.9) {
            lastUpdatePercent = percent;
            _updateItem(item.id, (i) => i.copyWith(
              progress: percent,
              statusMessage: 'Downloading: ${percent.toStringAsFixed(1)}%',
            ));
          }
        }

        await output.close();
        _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '✅ Binary download complete.']));

        if (item.type == DownloadType.audio) {
          // 1. FETCH LYRICS & RICH METADATA (Multi-Stage fallback)
          _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Fetching rich metadata...', logs: [...i.logs, '🔍 Searching LRCLIB for enhanced metadata...']));
          String albumName = 'Resonance Downloads'; 
          String trackTitle = video.title; 
          String trackArtist = video.author; 
          // Attempt to extract album from YouTube Description first as a solid hint
          try {
            final desc = video.description;
            final albumRegex = RegExp(r"Album\s*:\s*(.*)", caseSensitive: false);
            final match = albumRegex.firstMatch(desc);
            if (match != null && match.group(1) != null) {
              albumName = match.group(1)!.trim();
              _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '📝 Found album in description: $albumName']));
            }
          } catch (_) {}

          try {
            String cleanTitle = video.title
                .replaceAll(RegExp(r'\(official.*?\)|\[official.*?\]|\(music video\)|\(lyric.*?\)|\[lyric.*?\]|\(audio\)|\(video\)|\[mv\]', caseSensitive: false), '')
                .replaceAll(RegExp(r'vevo', caseSensitive: false), '')
                .trim();
            
            // 1. Membersihkan nama artis mirip seperti _primary_artist di Python
            String cleanArtist = video.author
                .replaceAll(RegExp(r'\s*-\s*topic$|\s*vevo$|\s*official$|\s*music$|\s*tv$', caseSensitive: false), '')
                .trim();
            // Mengambil artis utama saja jika ada koma
            cleanArtist = cleanArtist.split(',').first.trim();

            final searchStages = [
              {'q': '$cleanTitle $cleanArtist', 'label': 'Exact'},
              {'q': cleanTitle, 'label': 'Title-only'},
            ];

            bool metadataFound = false;
            for (final stage in searchStages) {
              if (metadataFound) break;
              
              final label = stage['label'];
              final query = stage['q'];
              _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '🔎 Lyrics [$label]: "$query"']));

              final lrcUrl = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(query!)}');
              final lrcReq = await HttpClient().getUrl(lrcUrl);
              final lrcRes = await lrcReq.close();
              final responseBody = await lrcRes.transform(utf8.decoder).join();
              
              final List<dynamic> results = jsonDecode(responseBody);
              if (results.isNotEmpty) {
                final bestMatch = results.first;
                
                final String? apiArtist = bestMatch['artistName']?.toString().toLowerCase();
                final String youtubeArtist = cleanArtist.toLowerCase();
                final bool isArtistMatch = apiArtist != null && (apiArtist.contains(youtubeArtist) || youtubeArtist.contains(apiArtist));

                // PERBAIKAN BUG: Lirik hanya disimpan JIKA artisnya cocok atau tahap Exact!
                if (label == 'Exact' || isArtistMatch) {
                   if (bestMatch['albumName'] != null) albumName = bestMatch['albumName'];
                   if (bestMatch['trackName'] != null) trackTitle = bestMatch['trackName'];
                   if (bestMatch['artistName'] != null) trackArtist = bestMatch['artistName'];
                   _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '📦 Verified metadata match: $trackTitle - $trackArtist']));
                   
                   // Pindahkan logika penyimpanan lirik ke DALAM blok validasi ini
                   final syncedLyrics = bestMatch['syncedLyrics'];
                   final lyricsToSave = syncedLyrics ?? bestMatch['plainLyrics'];

                   if (lyricsToSave != null && lyricsToSave.toString().isNotEmpty) {
                     final lyricsDir = Directory(settings.lyricsOutputPath.isNotEmpty 
                         ? settings.lyricsOutputPath : await PathUtils.getLyricsDefault());
                     if (!await lyricsDir.exists()) await lyricsDir.create(recursive: true);
                     
                     final lrcFile = File(p.join(lyricsDir.path, '$locId.lrc'));
                     await lrcFile.writeAsString(lyricsToSave.toString());
                     _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '✅ Lyrics found & saved.']));
                   }
                   metadataFound = true; // Hentikan pencarian karena sudah ketemu yang valid
                   
                } else {
                   _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, 'ℹ Result found but identity mismatch. Skipping.']));
                   // Biarkan metadataFound = false agar sistem mencoba searchStages berikutnya
                }
              }
            }

            if (!metadataFound) {
              _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '❌ No lyrics found in any stage.']));
            }
          } catch (e) {
            _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '⚠ Metadata search error: $e']));
          }

          _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '🏷 Album assigned: $albumName']));

          // 2. FETCH THUMBNAIL (iTunes API Pertama, YouTube Fallback)
          _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Downloading cover art...', logs: [...i.logs, '🖼 Fetching high-resolution cover art...']));
          List<int> imageBytes = [];
          try {
            String? artworkUrl;
            
            // Coba iTunes API untuk cover art 1:1 kualitas tinggi
            try {
              final itunesUrl = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent("$trackTitle $trackArtist")}&media=music&limit=1');
              final itunesReq = await HttpClient().getUrl(itunesUrl);
              final itunesRes = await itunesReq.close();
              final itunesBody = await itunesRes.transform(utf8.decoder).join();
              final itunesData = jsonDecode(itunesBody);
              
              if (itunesData['results'] != null && itunesData['results'].isNotEmpty) {
                // Ambil gambar resolusi 600x600px
                artworkUrl = itunesData['results'][0]['artworkUrl100']?.toString().replaceAll('100x100bb', '600x600bb');
              }
            } catch (e) {
              _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, 'ℹ iTunes fallback active.']));
            }

            // Jika iTunes gagal, fallback ke YouTube Thumbnail
            if (artworkUrl == null || artworkUrl.isEmpty) {
              if (video.thumbnails.maxResUrl.isNotEmpty) artworkUrl = video.thumbnails.maxResUrl;
              else if (video.thumbnails.standardResUrl.isNotEmpty) artworkUrl = video.thumbnails.standardResUrl;
              else if (video.thumbnails.highResUrl.isNotEmpty) artworkUrl = video.thumbnails.highResUrl;
              else artworkUrl = video.thumbnails.mediumResUrl;
            }

            final thumbUrl = Uri.parse(artworkUrl);
            final request = await HttpClient().getUrl(thumbUrl);
            final response = await request.close();
            imageBytes = await response.expand((chunk) => chunk).toList();
          } catch (e) {
            _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '⚠ Artwork error: $e']));
          }
          
          if (imageBytes.isNotEmpty) {
             _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '🎨 Cover art resolved (${(imageBytes.length / 1024).toStringAsFixed(0)} KB)']));
          }

          // 3. APPLY METADATA (TAGS) KE DALAM FILE AUDIO
          _updateItem(item.id, (i) => i.copyWith(statusMessage: 'Applying tags...', logs: [...i.logs, '🏷 Writing ID3 tags (Title, Artist, Album, Art)...']));
          try {
            final tag = tags.Tag(
              title: trackTitle,
              trackArtist: trackArtist,
              album: albumName,
              pictures: imageBytes.isNotEmpty 
                  ? [tags.Picture(
                      bytes: Uint8List.fromList(imageBytes), 
                      mimeType: tags.MimeType.jpeg, 
                      pictureType: tags.PictureType.coverFront
                    )]
                  : [],
            );
            await tags.AudioTags.write(filePath, tag);
          } catch (e) {
            _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '⚠ Tag error: $e']));
          }

          // 4. SIDE CARS: Save .jpg for Resonance standards
          final imagesDir = await ref.read(cacheManagerProvider).getImagesDir();
          final targetArt = p.join(imagesDir.path, 'art_$locId.jpg');
          try {
            // Write art sidecar
            if (imageBytes.isNotEmpty) {
              final artFile = File(targetArt);
              await artFile.writeAsBytes(imageBytes);
            }
          } catch (e) {
             _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, '⚠ Sidecar error: $e']));
          }

          // Instant Sync with Library (Audio)
          ref.read(libraryProvider.notifier).addMediaItem(MediaItem(
            id: locId,
            path: filePath,
            title: trackTitle,
            artist: trackArtist,
            album: albumName,
            thumbnailUrl: targetArt,
            type: 'audio',
          ));
        } else {
          // Instant Sync with Library (Video)
          ref.read(libraryProvider.notifier).addMediaItem(MediaItem(
            id: locId,
            path: filePath,
            title: video.title,
            type: 'video',
          ));
        }

        _updateItem(item.id, (i) => i.copyWith(
          status: DownloadStatus.done,
          progress: 100.0,
          outputPath: filePath,
          statusMessage: 'Download complete',
          logs: [...i.logs, '🏁 Finalizing... Success!']
        ));

        success = true;
        _scheduleNext();

      } catch (e) {
        final errStr = e.toString().toLowerCase();
        
        // GLOBAL CIRCUIT BREAKER for Rate Limiting (429)
        if (errStr.contains('requestlimitexceeded') || errStr.contains('ratelimit') || errStr.contains('429')) {
          _isRateLimited = true;
          _rateLimitResetTime = DateTime.now().add(const Duration(minutes: 15));
          _updateItem(item.id, (i) => i.copyWith(
            status: DownloadStatus.error, 
            errorMessage: 'YouTube Rate Limited (429). Queue paused for 15m.',
            logs: [...i.logs, '🔴 $e']
          ));
          _emitGlobalError('YouTube IP Rate Limit detected! Pausing all downloads.');
          break; // Stop attempting this item and break the while loop
        }

        if (attempt >= maxAttempts) {
          _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.error, errorMessage: e.toString()));
          _scheduleNext();
        } else {
          _updateItem(item.id, (i) => i.copyWith(logs: [...i.logs, 'Attempt $attempt failed: $e']));
        }
      } finally {
        ytClient.close();
      }
    }
  }

  Future<int> _getAndroidSdkInt() async {
    try {
      if (Platform.isAndroid) {
        final versionString = Platform.operatingSystemVersion;
        final match = RegExp(r'SDK\s+(\d+)').firstMatch(versionString);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      }
    } catch (_) {}
    return 33; 
  }

  void _emitGlobalError(String message) {
    // ignore: avoid_print
    print('[DownloadNotifier] ERROR: $message');
  }

}
