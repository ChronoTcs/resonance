import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/path_utils.dart';

final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager();
});

class CacheManager {
  String? _customCachePath;
  Future<void>? _lastWriteOperation;

  void setCustomPath(String? path) => _customCachePath = path;

  Future<Directory> getBaseCacheDir() async => _baseCacheDir;

  // ---------------- Directories ---------------- 

  Future<Directory> get _baseCacheDir async {
    if (_customCachePath != null) {
      final dir = Directory(_customCachePath!);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }
    
    // Read from SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final overridePath = prefs.getString('cache_folder');
      if (overridePath != null && overridePath.isNotEmpty) {
        final dir = Directory(overridePath);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    } catch (_) {}

    final path = await PathUtils.getCacheDefault();
    final cacheDir = Directory(path);
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // ── Local (Downloaded) Directories ──

  Future<Directory> getLocalMusicDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final overridePath = prefs.getString('music_folder');
      if (overridePath != null && overridePath.isNotEmpty) {
        final dir = Directory(overridePath);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    } catch (_) {}

    final path = await PathUtils.getMusicDefault();
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getLocalLyricsDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicOverride = prefs.getString('music_folder');
      if (musicOverride != null && musicOverride.isNotEmpty) {
        final dir = Directory(p.join(Directory(musicOverride).parent.path, 'lyrics'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    } catch (_) {}

    final path = await PathUtils.getLyricsDefault();
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getLocalImagesDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicOverride = prefs.getString('music_folder');
      if (musicOverride != null && musicOverride.isNotEmpty) {
        final dir = Directory(p.join(Directory(musicOverride).parent.path, 'images'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    } catch (_) {}

    final path = await PathUtils.getLocalImagesDefault();
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── Stream Directories (top-level sibling of cache/) ──

  Future<Directory> getStreamDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final overridePath = prefs.getString('stream_folder');
      if (overridePath != null && overridePath.isNotEmpty) {
        final dir = Directory(overridePath);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    } catch (_) {}

    // stream/ is top-level next to cache/, not nested inside it
    final base = await _baseCacheDir;
    final streamPath = p.join(p.dirname(base.path), 'stream');
    final dir = Directory(streamPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getStreamAudioDir() async {
    final streamDir = await getStreamDir();
    final dir = Directory(p.join(streamDir.path, 'audio'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getStreamImagesDir() async {
    final streamDir = await getStreamDir();
    final dir = Directory(p.join(streamDir.path, 'images'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getStreamLyricsDir() async {
    final streamDir = await getStreamDir();
    final dir = Directory(p.join(streamDir.path, 'lyrics'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getMetadataDir() async {
    final base = await _baseCacheDir;
    final dir = Directory(p.join(base.path, 'metadata'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> getTranslateDir() async {
    final base = await _baseCacheDir;
    final dir = Directory(p.join(base.path, 'translate'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> updateLastAccessed(File file) async {
    if (await file.exists()) {
      try {
        await file.setLastModified(DateTime.now());
      } catch (e) {
        debugPrint('CacheManager: Failed to update last accessed for ${file.path}: $e');
      }
    }
  }

  // ---------------- Filename Utility ---------------- 

  String getSafeFilename(String id) {
    // 1. Clean non-alphanumeric characters (consistent with Android Downloader)
    String sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    
    // 2. Limit length and add hash if too long (prevents Windows Path Limit)
    if (sanitized.length > 64) {
      int hash = 0;
      for (var i = 0; i < id.length; i++) {
        hash = (hash << 5) - hash + id.codeUnitAt(i);
        hash &= 0x7FFFFFFF;
      }
      return "${sanitized.substring(0, 32)}_h${hash.toRadixString(16)}";
    }
    return sanitized;
  }

  // ---------------- File I/O with Mutex ---------------- 

  /// Ensures that file writing happens sequentially to avoid I/O leaks / corruption.
  Future<void> synchronizedWrite(File file, String content) async {
    // Chain futures so that the next write waits for the previous to finish
    Future<void> writeOp = (_lastWriteOperation ?? Future.value()).then((_) async {
      final tempFile = File('${file.path}.tmp');
      try {
        await tempFile.writeAsString(content);
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
      } catch (e) {
        debugPrint('CacheManager sync write failed: $e');
        if (await tempFile.exists()) {
          try {
            await tempFile.copy(file.path);
            await tempFile.delete();
          } catch (_) {}
        }
      }
    });

    _lastWriteOperation = writeOp;
    await writeOp;
  }

  // ---------------- Enforce Bounds (Limit/Cleanup) ---------------- 

  /// Enforce MB limit strictly on stream/audio.
  Future<void> enforceStreamAudioLimit(int limitMb) async {
    try {
      final dir = await getStreamAudioDir();
      if (!dir.existsSync()) return;

      final result = await Isolate.run(() => _scanAndSortFiles(dir.path, limitMb));
      final List<File> filesToDelete = result.pathsToDelete.map((p) => File(p)).toList();
      if (filesToDelete.isEmpty) return;

      debugPrint('Stream audio limit exceeded: ${result.currentSizeMb.toStringAsFixed(2)}MB > ${limitMb}MB. Cleaning up...');
      for (var file in filesToDelete) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Failed to delete ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('Enforce cache limit error: $e');
    }
  }

  /// Cleans up temporary stream images and lyrics to prevent piling up.
  /// Only deletes orphaned files (where corresponding audio stream was already deleted/erased)
  /// AND the secondary file age exceeds [maxAgeDays].
  Future<void> cleanupTemporaryStreams({int maxAgeDays = 7}) async {
    try {
      final audioDir = await getStreamAudioDir();
      final imgsDir = await getStreamImagesDir();
      final lrcDir = await getStreamLyricsDir();
      
      final maxAge = Duration(days: maxAgeDays);
      final now = DateTime.now();

      // Collect existing audio song IDs (without extension)
      final Set<String> existingAudioIds = {};
      if (await audioDir.exists()) {
        await for (var entity in audioDir.list(recursive: false)) {
          if (entity is File) {
            existingAudioIds.add(p.basenameWithoutExtension(entity.path));
          }
        }
      }

      for (var dir in [imgsDir, lrcDir]) {
        if (!await dir.exists()) continue;
        await for (var entity in dir.list(recursive: false)) {
          if (entity is File) {
            try {
              final basename = p.basenameWithoutExtension(entity.path);
              // Art files are named 'art_{id}' — strip prefix if present
              final songId = basename.startsWith('art_') ? basename.substring(4) : basename;

              // Orphan guard: Only delete if the audio file was already erased
              if (!existingAudioIds.contains(songId)) {
                final stat = await entity.stat();
                if (now.difference(stat.modified) > maxAge) {
                  await entity.delete();
                  debugPrint('CacheManager: Cleaned up orphaned secondary stream file ${entity.path}');
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Cleanup temp streams error: $e');
    }
  }

  static _CacheScanResult _scanAndSortFiles(String dirPath, int limitMb) {
    final dir = Directory(dirPath);
    final allEntities = dir.listSync(recursive: false);
    final List<File> allFiles = [];
    int currentTotal = 0;
    
    for (var entity in allEntities) {
      if (entity is File) {
        allFiles.add(entity);
        currentTotal += entity.lengthSync();
      }
    }
    
    int limitBytes = limitMb * 1024 * 1024;
    if (currentTotal <= limitBytes) {
      return _CacheScanResult(currentSizeMb: currentTotal / 1024 / 1024, pathsToDelete: []);
    }
    
    // Sort oldest first
    allFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    
    final List<String> pathsToDelete = [];
    int bytesToRemove = currentTotal - limitBytes;
    int removedSoFar = 0;
    
    for (var file in allFiles) {
      if (removedSoFar >= bytesToRemove) break;
      pathsToDelete.add(file.path);
      removedSoFar += file.lengthSync();
    }
    
    return _CacheScanResult(currentSizeMb: currentTotal / 1024 / 1024, pathsToDelete: pathsToDelete);
  }
}

class _CacheScanResult {
  final double currentSizeMb;
  final List<String> pathsToDelete;
  _CacheScanResult({required this.currentSizeMb, required this.pathsToDelete});
}
