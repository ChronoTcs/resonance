import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/path_utils.dart';

final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager();
});

class CacheManager {
  String? _customCachePath;
  Future<void>? _lastWriteOperation;

  void setCustomPath(String? path) => _customCachePath = path;

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

  Future<Directory> getStreamDir() async {
    final base = await _baseCacheDir;
    final dir = Directory(p.join(base.path, 'stream'));
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

  Future<Directory> getImagesDir() async {
    final base = await _baseCacheDir;
    final path = base.path;
    final dir = (path.endsWith('images') || path.endsWith('images${Platform.pathSeparator}'))
        ? Directory(path)
        : Directory(p.join(path, 'images'));
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
    String sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitized.length > 128) {
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
  /// Standard retention: Delete files older than 7 days.
  Future<void> cleanupTemporaryStreams() async {
    try {
      final imgsDir = await getStreamImagesDir();
      final lrcDir = await getStreamLyricsDir();
      
      final maxAge = const Duration(days: 7);
      final now = DateTime.now();

      for (var dir in [imgsDir, lrcDir]) {
        if (!await dir.exists()) continue;
        await for (var entity in dir.list(recursive: false)) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              if (now.difference(stat.modified) > maxAge) {
                await entity.delete();
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
