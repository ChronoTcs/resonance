import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'data_usage_service.dart';
import '../../features/library/data/models/media_item.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  static String? _customCachePath;

  static void setCustomPath(String? path) => _customCachePath = path;

  Future<Directory> getCacheDir() => _cacheDir;

  Future<Directory> get _cacheDir async {
    if (_customCachePath != null) {
      final dir = Directory(_customCachePath!);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }

    String path;
    if (Platform.isWindows) {
      // Avoid OneDrive/Documents redirect if possible for a cleaner experience
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        path = p.join(userProfile, 'resonance_cache');
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        path = p.join(appDir.path, 'media_cache');
      }
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      path = p.join(appDir.path, 'media_cache');
    }

    final cacheDir = Directory(path);
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return cacheDir;
  }

  String getSafeFilename(String id) {
    // Replace any character that is not alphanumeric, underscore, or hyphen
    String sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    
    // Windows has a path limit (~260 chars). Long URLs as filenames will fail.
    // If the ID is too long, we use a prefix + deterministic hash of the full ID.
    if (sanitized.length > 128) {
      int hash = 0;
      for (var i = 0; i < id.length; i++) {
        hash = (hash << 5) - hash + id.codeUnitAt(i);
        hash &= 0x7FFFFFFF; // Keep it positive
      }
      // Combine first 32 chars of sanitized ID with hash for a unique, safe filename
      return "${sanitized.substring(0, 32)}_h${hash.toRadixString(16)}";
    }
    
    return sanitized;
  }

  // --- Audio Caching ---

  Future<String> getAudioPath(String songId, String streamUrl) async {
    final dir = await _cacheDir;
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));

    if (file.existsSync()) {
      return file.path;
    }

    // Background Download
    _downloadAudioInBackground(streamUrl, file.path);
    return streamUrl;
  }

  Future<String?> getCachedAudioPath(String songId) async {
    final dir = await _cacheDir;
    final safeId = getSafeFilename(songId);
    final file = File(p.join(dir.path, '$safeId.m4a'));
    return file.existsSync() ? file.path : null;
  }

  void _downloadAudioInBackground(String url, String savePath) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(savePath);
        final bytes = response.bodyBytes;
        await file.writeAsBytes(bytes);
        
        // Track data usage
        DataUsageService().addBytes(bytes.length);
        
        print('Audio cached: $savePath (${bytes.length} bytes)');
      }
    } catch (e) {
      print('Audio caching failed: $e');
    }
  }

  // --- Lyrics Caching ---

  Future<String?> getLyrics(String songId, Future<String?> Function() fetchLyrics) async {
    final dir = await _cacheDir;
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

  // --- Metadata Caching ---

  Future<void> saveArtToCache(String songId, Uint8List bytes) async {
    try {
      final dir = await _cacheDir;
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, 'art_$safeId.jpg'));
      if (!file.existsSync()) {
        await file.writeAsBytes(bytes);
      }
    } catch (e) {
      print('Art caching error: $e');
    }
  }

  Future<String?> getCachedArtPath(String songId) async {
    try {
      final dir = await _cacheDir;
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, 'art_$safeId.jpg'));
      return file.existsSync() ? file.path : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveMetadata(String songId, MediaItem item) async {
    try {
      final dir = await _cacheDir;
      final safeId = getSafeFilename(songId);
      final file = File(p.join(dir.path, '$safeId.json'));
      
      // Convert MediaItem to Map then to JSON
      // Note: albumArt (Uint8List) needs to be base64 encoded for JSON
      final map = item.toJson();
      if (item.albumArt != null) {
        map['albumArtBase64'] = base64Encode(item.albumArt!);
      }

      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      print('Metadata caching error: $e');
    }
  }

  Future<MediaItem?> getCachedMetadata(String songId) async {
    try {
      final dir = await _cacheDir;
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

  // --- Cache Management ---

  Future<String> getCacheSize() async {
    try {
      final dir = await _cacheDir;
      int totalSize = 0;
      if (dir.existsSync()) {
        dir.listSync(recursive: true, followLinks: false).forEach((entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
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
      final dir = await _cacheDir;
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Clear cache error: $e');
    }
  }
}
