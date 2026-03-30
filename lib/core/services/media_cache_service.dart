import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'data_usage_service.dart';
import 'cache_manager.dart';
import '../../features/library/data/models/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mediaCacheServiceProvider = Provider<MediaCacheService>((ref) {
  final dataUsageService = ref.watch(dataUsageServiceProvider);
  final cacheManager = ref.watch(cacheManagerProvider);
  final service = MediaCacheService(dataUsageService, cacheManager);
  ref.onDispose(() => service.dispose()); // Dispose the client when the provider is disposed
  return service;
});

class MediaCacheService {
  final DataUsageService _dataUsageService;
  final CacheManager _cacheManager;
  final http.Client _client = http.Client(); // Persistent HTTP client
  Timer? _cleanupTimer;

  MediaCacheService(this._dataUsageService, this._cacheManager);

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

  Future<String> getAudioPath(String songId, String streamUrl) async {
    final dir = await _cacheManager.getStreamAudioDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));

    if (file.existsSync()) {
      debugPrint('MediaCacheService: Cache hit for $songId');
      return file.path;
    }

    // If currently being downloaded, the caller can wait for this future
    if (_activeDownloads.containsKey(songId)) {
      debugPrint('MediaCacheService: Existing prefetch in progress for $songId. Waiting...');
      await _activeDownloads[songId];
      if (file.existsSync()) return file.path;
    }

    debugPrint('MediaCacheService: Cache miss for $songId. Starting background cache...');
    final downloadFuture = _downloadAudioInBackground(songId, streamUrl, file.path);
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

  Future<void> _downloadAudioInBackground(String songId, String url, String savePath) async {
    final file = File(savePath);
    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(url));
      
      // Mimic a real browser/player to avoid bot detection/IP ban
      request.headers.addAll({
        'User-Agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
        'Connection': 'keep-alive',
        'Sec-Fetch-Dest': 'audio',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
      });
      
      final response = await _client.send(request).timeout(const Duration(minutes: 5));
      
      if (response.statusCode == 200) {
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
        print('Audio cached: $savePath ($downloadedBytes bytes)');
        
        _scheduleCleanup();
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MediaCacheService: Audio caching failed for $songId: $e');
      if (sink != null) await sink.close();
      if (file.existsSync()) {
        try { 
          await file.delete(); 
          debugPrint('MediaCacheService: Cleaned up partial file for $songId');
        } catch (_) {}
      }
    } finally {
      _activeDownloads.remove(songId);
    }
  }

  Future<String?> getLyrics(String songId, Future<String?> Function() fetchLyrics) async {
    final dir = await _cacheManager.getStreamLyricsDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.lrc'));

    if (file.existsSync()) {
      return await file.readAsString();
    }

    try {
      final lyrics = await fetchLyrics();
      if (lyrics != null && lyrics.isNotEmpty && !lyrics.contains('Not Found')) {
        await file.writeAsString(lyrics);
      }
      return lyrics;
    } catch (e) {
      print('Lyrics fetch/cache error: $e');
      return null;
    }
  }

  Future<String?> getCachedLyricsPath(String songId) async {
    final dir = await _cacheManager.getStreamLyricsDir();
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.lrc'));
    return file.existsSync() ? file.path : null;
  }

  Future<void> saveArtToCache(String songId, Uint8List bytes) async {
    try {
      final dir = await _cacheManager.getStreamImagesDir();
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, 'art_$safeId.jpg'));
      if (!file.existsSync()) {
        await file.writeAsBytes(bytes);
        _scheduleCleanup();
      }
    } catch (e) {
      print('Art caching error: $e');
    }
  }

  Future<String?> getCachedArtPath(String songId) async {
    try {
      final dir = await _cacheManager.getStreamImagesDir();
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, 'art_$safeId.jpg'));
      if (file.existsSync()) return file.path;

      // Check permanent images dir as fallback
      final permDir = await _cacheManager.getImagesDir();
      final permFile = File(p.join(permDir.path, 'art_$safeId.jpg'));
      if (permFile.existsSync()) return permFile.path;
      
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
      print('Metadata caching error: $e');
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
      print('Metadata retrieval error: $e');
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
      ];
      for (final file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
          print('Cache removal: Deleted ${p.basename(file.path)}');
        }
      }
    } catch (e) {
      print('Cache removal error for $songId: $e');
    }
  }

  Future<String> getCacheSize() async {
    try {
      // Calculate ONLY stream/audio to respect user's request:
      // "hanya untuk path folder audio di dalam folder stream"
      final audioDir = await _cacheManager.getStreamAudioDir();
      int totalSize = 0;
      if (audioDir.existsSync()) {
        await for (final entity in audioDir.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      if (totalSize < 1024) return '$totalSize B';
      if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(2)} KB';
      if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (e) {
      return '0 B';
    }
  }

  Future<void> clearCache() async {
    try {
      for (var getter in [
        _cacheManager.getStreamAudioDir,
        _cacheManager.getStreamImagesDir,
        _cacheManager.getStreamLyricsDir,
      ]) {
        final dir = await getter();
        if (dir.existsSync()) {
          final List<FileSystemEntity> entities = dir.listSync();
          for (final entity in entities) {
            if (entity is File) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      print('Clear cache error: $e');
    }
  }

  void _scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(seconds: 5), () {
      enforceCacheLimit(500);
      _cacheManager.cleanupTemporaryStreams();
    });
  }

  Future<void> enforceCacheLimit(int limitMb) async {
    await _cacheManager.enforceStreamAudioLimit(limitMb);
  }
}
