import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/core/utils/path_utils.dart';

class MusicRestoreService {
  final Ref _ref;

  MusicRestoreService(this._ref);

  /// If [manualPath] is provided (Windows), it uses that.
  /// If null and on Android, it attempts to auto-detect a connected source.
  Future<void> restoreFromSource(String? manualPath) async {
    String? sourcePath = manualPath;

    // 1. Android Auto-Detection Logic
    if (sourcePath == null) {
      if (Platform.isAndroid) {
        sourcePath = await _detectAndroidSourcePath();
      }
      
      if (sourcePath == null) {
        throw Exception('No external storage volume with Resonance/Music found.');
      }
    }

    // 2. SDK-aware Permission Guard (no MANAGE_EXTERNAL_STORAGE needed for public folders)
    if (Platform.isAndroid) {
      final sdkInt = await _getSdkInt();
      final bool hasPermission = sdkInt >= 33
          ? await Permission.audio.isGranted
          : await Permission.storage.isGranted;
      if (!hasPermission) {
        debugPrint('MusicRestoreService: Storage permission denied. Aborting.');
        return;
      }
    }

    final sourceDir = Directory(sourcePath);
    if (!await sourceDir.exists()) return;

    // 3. Fetch Dynamic Paths from LibraryProvider
    final libraryState = _ref.read(libraryProvider);
    final String? targetMusicPath = libraryState.musicFolderPath;
    final String? targetLyricsPath = libraryState.lyricsFolderPath;
    final String? targetCachePath = libraryState.cacheFolderPath;

    if (targetMusicPath == null || targetLyricsPath == null || targetCachePath == null) {
      debugPrint('MusicRestoreService: Target paths not initialized.');
      return;
    }

    final targetMusicDir = Directory(targetMusicPath);
    final targetLyricsDir = Directory(targetLyricsPath);
    // Art goes to local/images/, not cache/images/
    final targetImagesDir = Directory(await PathUtils.getLocalImagesDefault());

    if (!await targetMusicDir.exists()) await targetMusicDir.create(recursive: true);
    if (!await targetLyricsDir.exists()) await targetLyricsDir.create(recursive: true);
    if (!await targetImagesDir.exists()) await targetImagesDir.create(recursive: true);

    await _restoreAndRemapLibraryJson(sourcePath, targetMusicPath, targetImagesDir.path, manualPath: manualPath);

    // We search for the 'images' folder in both common and custom locations.
    Directory? sourceImagesDir;
    final sourceParent = sourceDir.parent;
    final List<String> possibleImagePaths = [
      p.join(sourcePath, 'local', 'images'),
      p.join(sourcePath, 'resonance_cache', 'images'),
      p.join(sourcePath, 'cache', 'images'),
      p.join(sourcePath, 'images'),
      p.join(sourceParent.path, 'local', 'images'),
      p.join(sourceParent.path, 'resonance_cache', 'images'),
      p.join(sourceParent.path, 'cache', 'images'),
      p.join(sourceParent.path, 'images'),
    ];
    
    for (var path in possibleImagePaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        sourceImagesDir = dir;
        debugPrint('MusicRestoreService: Found source images at -> $path');
        break;
      }
    }

    // 6. THE RECOVERY LOOP
    try {
      final List<FileSystemEntity> sourceEntities = sourceDir.listSync(recursive: true);
      
      for (var entity in sourceEntities) {
        if (entity is! File) continue;
        
        final ext = p.extension(entity.path).toLowerCase();
        if (!['.mp3', '.m4a', '.wav', '.flac'].contains(ext)) continue;

        final fileName = p.basename(entity.path);
        final baseName = p.basenameWithoutExtension(entity.path);
        final targetFilePath = p.join(targetMusicPath, fileName);
        final targetFile = File(targetFilePath);

        // A. Check if .mp3 exists locally
        if (!await targetFile.exists()) {
          // Copy .mp3
          await entity.copy(targetFilePath);
          debugPrint('MusicRestoreService: Restored local file -> $fileName');
        } else {
          // If ALREADY EXISTS, check file size to ensure integrity (Matching Strategy Basename + Size)
          final sourceSize = await entity.length();
          final targetSize = await targetFile.length();
          if (sourceSize != targetSize) {
            // Probably different file or corrupted, skip or overwrite? 
          }
        }

        // B. THE SUPPORT DATA RECOVERY (Partial & Full)
        
        // 1. Recover Lyrics (.lrc)
        final sourceLrcPath = p.join(sourcePath, 'Lyrics', '$baseName.lrc');
        final targetLrcPath = p.join(targetLyricsPath, 'Lyrics', '$baseName.lrc');
        if (await File(sourceLrcPath).exists()) {
          final targetLrcDir = Directory(p.dirname(targetLrcPath));
          if (!await targetLrcDir.exists()) {
            await targetLrcDir.create(recursive: true);
          }
          if (!await File(targetLrcPath).exists()) {
            await File(sourceLrcPath).copy(targetLrcPath);
            debugPrint('MusicRestoreService: Restored lyrics -> $baseName.lrc');
          }
        }

        // 2. THE HYBRID COVER ART LOGIC
        if (sourceImagesDir != null) {
          String? sourceArtFileName;
          String? targetArtFileName;

          if (baseName.startsWith('loc_')) {
            // IF DOWNLOADED FILE: ID is the filename
            sourceArtFileName = 'art_$baseName.jpg';
            targetArtFileName = sourceArtFileName;
          } else {
            // IF NORMAL LOCAL FILE: ID depends on the Parent Folder
            final sourceLocId = PathUtils.generateLocId(entity.path);
            final targetLocId = PathUtils.generateLocId(targetFilePath);
            
            sourceArtFileName = 'art_$sourceLocId.jpg';
            targetArtFileName = 'art_$targetLocId.jpg';
          }

          // Use the generated filenames to find and copy the art file
          final sourceArtFile = File(p.join(sourceImagesDir.path, sourceArtFileName));
          final targetArtFile = File(p.join(targetImagesDir.path, targetArtFileName));

          if (sourceArtFile.existsSync()) {
            if (!targetArtFile.existsSync()) {
              await sourceArtFile.copy(targetArtFile.path);
              debugPrint('MusicRestoreService: Restored Art -> $targetArtFileName');
            }
          }
        }
      }

      // 7. POST-RESTORE TRIGGER
      _ref.read(libraryProvider.notifier).scanLibrary(isBackground: false);
    } catch (e) {
      debugPrint('MusicRestoreService: Error during recovery loop: $e');
      rethrow;
    }
  }

  Future<void> _restoreAndRemapLibraryJson(String sourcePath, String targetMusicPath, String targetImagesPath, {String? manualPath}) async {
    try {
      final sourceDir = Directory(sourcePath);
      final sourceParent = sourceDir.parent;
      final cacheManager = _ref.read(cacheManagerProvider);
      final metadataDir = await cacheManager.getMetadataDir();

      final baseCacheDir = await cacheManager.getBaseCacheDir();

      // Strict Discovery Logic
      final possibleJsonPaths = [
        p.join(sourcePath, 'resonance_cache', 'resonance_library.json'),
        p.join(sourcePath, 'cache', 'resonance_library.json'),
        p.join(sourcePath, 'resonance_library.json'),
        p.join(sourcePath, 'resonance_cache', 'metadata', 'resonance_library.json'),
        p.join(sourcePath, 'metadata', 'resonance_library.json'),
        p.join(sourcePath, 'cache', 'metadata', 'resonance_library.json'),
      ];

      // Local Self-Repair Fallback (Private Storage)
      // ONLY allow this if we are doing automatic discovery (no manual path provided)
      bool isManualSelection = sourcePath == manualPath && manualPath != null;
      if (!isManualSelection) {
        possibleJsonPaths.add(p.join(baseCacheDir.path, 'resonance_library.json'));
        possibleJsonPaths.add(p.join(metadataDir.path, 'resonance_library.json'));
      }

      // Add parent paths ONLY if NOT in Android Internal Storage root (to avoid system folder permission errors)
      bool isAndroidInternal = Platform.isAndroid && sourcePath.startsWith('/storage/emulated/0');
      if (!isAndroidInternal) {
        possibleJsonPaths.addAll([
          p.join(sourceParent.path, 'resonance_cache', 'resonance_library.json'),
          p.join(sourceParent.path, 'cache', 'resonance_library.json'),
          p.join(sourceParent.path, 'resonance_cache', 'metadata', 'resonance_library.json'),
          p.join(sourceParent.path, 'cache', 'metadata', 'resonance_library.json'),
        ]);
      }

      File? sourceJsonFile;
      for (var path in possibleJsonPaths) {
        debugPrint('MusicRestoreService: Checking metadata path -> $path');
        final file = File(path);
        if (await file.exists()) {
          sourceJsonFile = file;
          break;
        }
      }

      // Skip scanning Parent on Android Internal root to avoid /Android/data crash logs
      if (sourceJsonFile == null) {
        debugPrint('MusicRestoreService: Standard paths failed. Performing discovery in $sourcePath...');
        final List<Directory> searchDirs = [sourceDir];
        
        if (!isAndroidInternal && await sourceParent.exists()) {
           searchDirs.add(sourceParent);
        }

        for (var dir in searchDirs) {
          try {
            final stream = dir.list(recursive: true, followLinks: false).handleError((e) {
              // Silently skip permission errors to keep logs clean
              if (!e.toString().contains('Permission denied')) {
                debugPrint('MusicRestoreService: Skipping folder during aggressive scan: $e');
              }
            }).take(500);

            await for (var entity in stream) {
              if (entity is File && p.basename(entity.path) == 'resonance_library.json') {
                sourceJsonFile = entity;
                debugPrint('MusicRestoreService: Aggressive Discovery found metadata at -> ${entity.path}');
                break;
              }
            }
          } catch (e) {
            debugPrint('MusicRestoreService: Aggressive scan error in ${dir.path}: $e');
          }
          if (sourceJsonFile != null) break;
        }
      }

      if (sourceJsonFile == null) {
        debugPrint('MusicRestoreService: No source resonance_library.json found. Skipping instant awakening.');
        return;
      }

      debugPrint('MusicRestoreService: Borrowing JSON from ${sourceJsonFile.path}');

      final String content = await sourceJsonFile.readAsString();
      
      final String remappedContent = await compute(_remapJsonIsolate, {
        'content': content,
        'targetMusicPath': targetMusicPath,
        'targetImagesPath': targetImagesPath,
      });

      final targetJsonFile = File(p.join(baseCacheDir.path, 'resonance_library.json'));

      await cacheManager.synchronizedWrite(targetJsonFile, remappedContent);
      debugPrint('MusicRestoreService: Metadata successfully re-mapped and restored.');

      // Atomic Refresh UI
      await _ref.read(libraryProvider.notifier).loadMetadataFromCache();
    } catch (e) {
      debugPrint('MusicRestoreService: Error during JSON re-mapping (V13.8): $e');
    }
  }

  Future<int> _getSdkInt() async {
    try {
      final match = RegExp(r'SDK\s+(\d+)').firstMatch(Platform.operatingSystemVersion);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 33; // fallback: assume modern
  }

  Future<String?> _detectAndroidSourcePath() async {
    try {
      final List<Directory>? dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs == null || dirs.isEmpty) return null;

      final libraryState = _ref.read(libraryProvider);
      final currentMusicPath = libraryState.musicFolderPath;

      for (var dir in dirs) {
        final String path = dir.path;
        final String volumeRoot = path.split('/Android/').first;
        
        final possiblePaths = [
          p.join(volumeRoot, 'Resonance', 'Music'),
          p.join(volumeRoot, 'Music', 'Resonance'),
          p.join(volumeRoot, 'Resonance'),
        ];

        for (var checkPath in possiblePaths) {
          if (await Directory(checkPath).exists()) {
            if (currentMusicPath != null && p.canonicalize(checkPath) == p.canonicalize(currentMusicPath)) {
               continue;
            }
            debugPrint('MusicRestoreService: Auto-detected structural source -> $checkPath');
            return checkPath;
          }
        }
      }
    } catch (e) {
      debugPrint('MusicRestoreService: Auto-detection error (V13.4): $e');
    }
    return null;
  }
}

/// Robust enough to handle cross-platform paths (Windows \ and Unix /)
String _remapJsonIsolate(Map<String, dynamic> args) {
  final String content = args['content'];
  final String targetMusicPath = args['targetMusicPath'];
  final String targetImagesPath = args['targetImagesPath'];

  // Helper to get basename regardless of platform
  String getUniversalBasename(String path) {
    if (path.contains('\\')) {
      return path.split('\\').last;
    }
    return p.basename(path);
  }

  try {
    final List<dynamic> items = jsonDecode(content);
    for (var item in items) {
      if (item is Map) {
        // 1. Remap File Path
        final oldPath = item['path'] as String?;
        if (oldPath != null && !oldPath.startsWith('http')) {
          item['path'] = p.join(targetMusicPath, getUniversalBasename(oldPath));
        }

        // 2. Remap Thumbnail URL (Local Art)
        final oldThumb = item['thumbnailUrl'] as String?;
        if (oldThumb != null && !oldThumb.startsWith('http')) {
          item['thumbnailUrl'] = p.join(targetImagesPath, getUniversalBasename(oldThumb));
        }
      }
    }
    return jsonEncode(items);
  } catch (e) {
    debugPrint('Isolate Surgery Error (V13.7): $e');
    return content;
  }
}

final musicRestoreServiceProvider = Provider<MusicRestoreService>((ref) {
  return MusicRestoreService(ref);
});
