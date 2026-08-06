import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';

import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/core/utils/path_utils.dart';

class LibraryRepository {
  final CacheManager _cacheManager;
  bool _isSaving = false;

  LibraryRepository(this._cacheManager);

  Future<File> _getCacheFile() async {
    final dir = await _cacheManager.getBaseCacheDir();
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

    // 2. Differential Scan (Use Path and ID to prevent OS-level Absolute Path mismatches)
    final Map<String, MediaItem> existingMapByPath = {};
    final Map<String, MediaItem> existingMapById = {};
    for (var item in existingItems) {
      existingMapByPath[item.path] = item;
      if (item.id != null) existingMapById[item.id!] = item;
    }

    final List<String> pathsToParse = [];
    final List<MediaItem> finalItems = [...videoItems];

    final localImagesDir = await _cacheManager.getLocalImagesDir();
    final streamImagesDir = await _cacheManager.getStreamImagesDir();

    for (var path in audioPaths) {
      MediaItem? existingItem = existingMapByPath[path];
      
      if (existingItem == null) {
        final fileName = p.basenameWithoutExtension(path);
        if (fileName.startsWith('loc_')) {
          existingItem = existingMapById[fileName];
        }
      }

      if (existingItem != null) {
        MediaItem item = existingItem;
        
        // Robust thumbnail check: Reconnect them whether they are null or pointing to a dead file
        if (item.thumbnailUrl == null || !item.thumbnailUrl!.startsWith('http')) {
          final id = item.id ?? p.basenameWithoutExtension(path);
          // Check local/images/ first, then stream/images/ as fallback
          final localThumb = p.join(localImagesDir.path, 'art_$id.jpg');
          final streamThumb = p.join(streamImagesDir.path, 'art_$id.jpg');
          final newThumbPath = File(localThumb).existsSync() ? localThumb
              : File(streamThumb).existsSync() ? streamThumb : null;

          if (newThumbPath != null) {
            if (item.thumbnailUrl != newThumbPath) {
              item = item.copyWith(thumbnailUrl: newThumbPath);
            }
          } else if (item.thumbnailUrl != null) {
            // Check if thumb migrated — search both domains
            final oldThumbFileName = p.basename(item.thumbnailUrl!);
            final movedLocal = p.join(localImagesDir.path, oldThumbFileName);
            final movedStream = p.join(streamImagesDir.path, oldThumbFileName);

            if (File(movedLocal).existsSync()) {
              if (item.thumbnailUrl != movedLocal) item = item.copyWith(thumbnailUrl: movedLocal);
            } else if (File(movedStream).existsSync()) {
              if (item.thumbnailUrl != movedStream) item = item.copyWith(thumbnailUrl: movedStream);
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
        'localImagesDirPath': localImagesDir.path,
        'streamImagesDirPath': streamImagesDir.path,
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
  final String localImagesDirPath = args['localImagesDirPath'] as String;
  final String streamImagesDirPath = args['streamImagesDirPath'] as String;
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

    String? setVideoId;
    try {
      final file = File(path);
      if (file.existsSync()) {
        final rawTag = readAllMetadata(file, getImage: false);
        
        // Populate setVideoId from container-specific frames
        if (rawTag is Mp3Metadata) {
          title = rawTag.songName?.isNotEmpty == true ? rawTag.songName! : title;
          artist = rawTag.leadPerformer ?? rawTag.bandOrOrchestra;
          setVideoId = rawTag.customMetadata['YT_ID'];
        } else if (rawTag is VorbisMetadata) {
          title = rawTag.title.firstOrNull?.isNotEmpty == true ? rawTag.title.first : title;
          artist = rawTag.artist.firstOrNull;
          final descTag = rawTag.description.firstWhere((d) => d.startsWith('YT_ID:'), orElse: () => '');
          if (descTag.isNotEmpty) {
            setVideoId = descTag.replaceFirst('YT_ID:', '');
          }
        } else if (rawTag is Mp4Metadata) {
          title = rawTag.title?.isNotEmpty == true ? rawTag.title! : title;
          artist = rawTag.artist;
          final lyrics = rawTag.lyrics ?? '';
          final match = RegExp(r'YT_ID:(.*)').firstMatch(lyrics);
          if (match != null) {
            setVideoId = match.group(1)?.trim();
          }
        }
      }
    } catch (e) {
      debugPrint('LibraryRepository Isolate: Metadata extraction error for $path: $e');
    }

    // Attach local art cover — check local/images/ first, then stream/images/
    final dir = p.dirname(path);
    final localCentralArt = File(p.join(localImagesDirPath, 'art_$id.jpg'));
    final streamCentralArt = File(p.join(streamImagesDirPath, 'art_$id.jpg'));
    final fallbackArtFile = File(p.join(dir, 'art_$id.jpg'));
    String? localThumbnailUrl;

    if (localCentralArt.existsSync()) {
      localThumbnailUrl = localCentralArt.path;
    } else if (streamCentralArt.existsSync()) {
      localThumbnailUrl = streamCentralArt.path;
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
      setVideoId: setVideoId,
    ));
  }
  return results;
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return LibraryRepository(cacheManager);
});
