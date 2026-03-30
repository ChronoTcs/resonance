import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';

import 'package:resonance_app/core/services/cache_manager.dart';
import 'package:resonance_app/core/utils/path_utils.dart';

class LibraryRepository {
  final CacheManager _cacheManager;
  bool _isSaving = false;

  LibraryRepository(this._cacheManager);

  Future<File> _getCacheFile() async {
    final dir = await _cacheManager.getMetadataDir();
    return File(p.join(dir.path, 'resonance_library.json'));
  }

  Future<void> saveLibraryCache(List<MediaItem> items) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final file = await _getCacheFile();
      final jsonList = items.map((e) => e.toJson(includeArt: false)).toList();
      final content = jsonEncode(jsonList);
      
      await _cacheManager.synchronizedWrite(file, content);
    } catch (e) {
      debugPrint('LibraryRepository: Failed to save cache: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<List<MediaItem>> loadLibraryCache() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      return await compute(_parseLibraryJson, content);
    } catch (e) {
      return [];
    }
  }

  /// High-Performance Library Scan using Sidecar JSONs
  Future<List<MediaItem>> scanLibrary({
    required String? musicFolderPath,
    required String? videoFolderPath,
    List<MediaItem> existingItems = const [],
  }) async {
    final List<String> audioPaths = [];
    final List<MediaItem> videoItems = [];

    // 1. Collect files from disk
    if (musicFolderPath != null) {
      final musicDir = Directory(musicFolderPath);
      if (await musicDir.exists()) {
        // Collect files
        await for (final entity in musicDir.list(recursive: true)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (['.mp3', '.m4a', '.wav', '.flac'].contains(ext)) {
              audioPaths.add(entity.path);
            }
          }
        }

      }
    }

    if (videoFolderPath != null) {
      final videoDir = Directory(videoFolderPath);
      if (await videoDir.exists()) {
        await for (final entity in videoDir.list(recursive: true)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (['.mp4', '.mkv', '.avi', '.mov'].contains(ext)) {
              videoItems.add(
                MediaItem(
                  path: entity.path,
                  title: p.basenameWithoutExtension(entity.path),
                  type: 'video',
                ),
              );
            }
          }
        }
      }
    }

    // 2. Differential Scan (Use Path as key since we haven't resolved IDs for these yet)
    final Map<String, MediaItem> existingMap = {
      for (var item in existingItems) item.path: item,
    };

    final List<String> pathsToParse = [];
    final List<MediaItem> finalItems = [...videoItems];

    final imagesDir = await _cacheManager.getImagesDir();

    for (var path in audioPaths) {
      if (existingMap.containsKey(path)) {
        MediaItem item = existingMap[path]!;
        
        // Robust thumbnail check: Reconnect them whether they are null or pointing to a dead file
        if (item.thumbnailUrl == null || !item.thumbnailUrl!.startsWith('http')) {
          final id = item.id ?? p.basenameWithoutExtension(path);
          final newThumbPath = p.join(imagesDir.path, 'art_$id.jpg');
          
          if (File(newThumbPath).existsSync()) {
            if (item.thumbnailUrl != newThumbPath) {
              item = item.copyWith(thumbnailUrl: newThumbPath);
            }
          } else if (item.thumbnailUrl != null) {
            // Check if the previous file simply migrated to the new central cache
            final oldThumbFileName = p.basename(item.thumbnailUrl!);
            final exactMovedThumb = p.join(imagesDir.path, oldThumbFileName);
            
            if (File(exactMovedThumb).existsSync()) {
              if (item.thumbnailUrl != exactMovedThumb) {
                item = item.copyWith(thumbnailUrl: exactMovedThumb);
              }
            } else {
               final oldThumbFile = File(item.thumbnailUrl!);
               if (!oldThumbFile.existsSync()) {
                 item = item.copyWith(clearThumbnailUrl: true);
               }
            }
          }
        }

        finalItems.add(item);
      } else {
        pathsToParse.add(path);
      }
    }

    if (pathsToParse.isEmpty) return finalItems;

    // 3. Batch Parse remainder (legacy or new files)
    final List<MediaItem> parsedItems = await compute(
      _parseBatch,
      {
        'paths': pathsToParse,
        'imagesDirPath': imagesDir.path,
      },
    );

    return [...finalItems, ...parsedItems];
  }
}

List<MediaItem> _parseLibraryJson(String content) {
  try {
    final List<dynamic> jsonList = jsonDecode(content);
    return jsonList.map((e) => MediaItem.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
}

String _generateLocId(String path) {
  // Pass the raw path string (without extension) if not known
  return PathUtils.generateLocId(path);
}

Future<List<MediaItem>> _parseBatch(Map<String, dynamic> args) async {
  final List<String> paths = args['paths'] as List<String>;
  final String imagesDirPath = args['imagesDirPath'] as String;
  final List<MediaItem> results = [];
  


  for (var path in paths) {
    String title = p.basenameWithoutExtension(path);
    String? artist;
    String fileName = p.basenameWithoutExtension(path);
    String id;

    // 1. If already loc_ prefix, keep it
    if (fileName.startsWith('loc_')) {
      id = fileName;
    }
    // 3. Fallback: generate loc_ ID
    else {
      id = _generateLocId(path);
    }

    try {
      final tag = await AudioTags.read(path);
      if (tag != null) {
        title = (tag.title != null && tag.title!.isNotEmpty) 
            ? tag.title! 
            : title;
        artist = tag.trackArtist ?? tag.albumArtist;
      }
    } catch (_) {}

    // Attach local art cover if exists (New strict loc_ format)
    final dir = p.dirname(path);
    final centralArtFile = File(p.join(imagesDirPath, 'art_$id.jpg'));
    final fallbackArtFile = File(p.join(dir, 'art_$id.jpg'));
    String? localThumbnailUrl;
    
    if (centralArtFile.existsSync()) {
      localThumbnailUrl = centralArtFile.path;
    } else if (fallbackArtFile.existsSync()) {
      localThumbnailUrl = fallbackArtFile.path;
    } else {
      // Legacy Fallback: Look for any art_*.jpg file in the directory that contains the track title
      try {
        final legacyArts = Directory(dir).listSync()
            .whereType<File>()
            .where((f) {
               final name = p.basename(f.path).toLowerCase();
               return name.startsWith('art_') && 
                      name.endsWith('.jpg') && 
                      name.contains(title.toLowerCase());
            });
            
        if (legacyArts.isNotEmpty) {
           localThumbnailUrl = legacyArts.first.path;
        }
      } catch (_) {}
    }

    results.add(MediaItem(
      id: id,
      path: path,
      title: title,
      artist: artist,
      thumbnailUrl: localThumbnailUrl,
      type: 'audio',
    ));
  }
  return results;
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return LibraryRepository(cacheManager);
});
