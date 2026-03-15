import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:audiotags/audiotags.dart';
import '../../../../core/services/media_cache_service.dart';
import '../models/media_item.dart';

class LibraryState {
  final List<MediaItem> allMedia;
  final bool isLoading;
  final String? musicFolderPath;
  final String? videoFolderPath;
  final String? lyricsFolderPath;
  final String? cacheFolderPath;

  LibraryState({
    this.allMedia = const [],
    this.isLoading = false,
    this.musicFolderPath,
    this.videoFolderPath,
    this.lyricsFolderPath,
    this.cacheFolderPath,
  });

  LibraryState copyWith({
    List<MediaItem>? allMedia,
    bool? isLoading,
    String? musicFolderPath,
    String? videoFolderPath,
    String? lyricsFolderPath,
    String? cacheFolderPath,
  }) {
    return LibraryState(
      allMedia: allMedia ?? this.allMedia,
      isLoading: isLoading ?? this.isLoading,
      musicFolderPath: musicFolderPath ?? this.musicFolderPath,
      videoFolderPath: videoFolderPath ?? this.videoFolderPath,
      lyricsFolderPath: lyricsFolderPath ?? this.lyricsFolderPath,
      cacheFolderPath: cacheFolderPath ?? this.cacheFolderPath,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    _loadSavedPaths();
    return LibraryState();
  }

  Future<void> _loadSavedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final musicPath = prefs.getString('music_folder');
    final videoPath = prefs.getString('video_folder');
    final lyricsPath = prefs.getString('lyrics_folder');
    final cachePath = prefs.getString('cache_folder');

    state = state.copyWith(
      musicFolderPath: musicPath,
      videoFolderPath: videoPath,
      lyricsFolderPath: lyricsPath,
      cacheFolderPath: cachePath,
    );

    if (musicPath != null || videoPath != null) {
      scanLibrary();
    }
  }

  Future<void> setMusicFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('music_folder', path);
    state = state.copyWith(musicFolderPath: path);
    scanLibrary();
  }

  Future<void> setVideoFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('video_folder', path);
    state = state.copyWith(videoFolderPath: path);
    scanLibrary();
  }

  Future<void> setLyricsFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lyrics_folder', path);
    state = state.copyWith(lyricsFolderPath: path);
  }

  Future<void> setCacheFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_folder', path);
    state = state.copyWith(cacheFolderPath: path);
  }

  Future<void> scanLibrary() async {
    state = state.copyWith(isLoading: true);

    final List<MediaItem> mediaList = [];

    // Scan Music
    if (state.musicFolderPath != null) {
      final musicDir = Directory(state.musicFolderPath!);
      if (await musicDir.exists()) {
        final files = musicDir.listSync(recursive: true);
        for (var file in files) {
          if (file is File) {
            final ext = p.extension(file.path).toLowerCase();
            if (['.mp3', '.m4a', '.wav', '.flac'].contains(ext)) {
              String title = p.basenameWithoutExtension(file.path);
              String? artist;
              String? album;
              Uint8List? albumArt;

              String? thumbnailUrl;

              try {
                final tag = await AudioTags.read(file.path);
                if (tag != null) {
                  if (tag.title != null && tag.title!.isNotEmpty) {
                    title = tag.title!;
                  }
                  artist = tag.trackArtist ?? tag.albumArtist;
                  album = tag.album;
                  albumArt = tag.pictures.isNotEmpty
                      ? tag.pictures.first.bytes
                      : null;
                      
                  if (albumArt != null) {
                    final songId = file.path;
                    final cache = MediaCacheService();
                    await cache.saveArtToCache(songId, albumArt);
                    thumbnailUrl = await cache.getCachedArtPath(songId);
                    albumArt = null; // Free memory immediately
                  }
                }
              } catch (_) {
                // Ignore parse errors, fallback to defaults
              }

              mediaList.add(
                MediaItem(
                  path: file.path,
                  title: title,
                  artist: artist,
                  album: album,
                  albumArt: albumArt,
                  thumbnailUrl: thumbnailUrl,
                  type: 'audio',
                ),
              );
            }
          }
        }
      }
    }

    // Scan Video
    if (state.videoFolderPath != null) {
      final videoDir = Directory(state.videoFolderPath!);
      if (await videoDir.exists()) {
        final files = videoDir.listSync(recursive: true);
        for (var file in files) {
          if (file is File) {
            final ext = p.extension(file.path).toLowerCase();
            if (['.mp4', '.mkv', '.avi', '.mov'].contains(ext)) {
              mediaList.add(
                MediaItem(
                  path: file.path,
                  title: p.basenameWithoutExtension(file.path),
                  type: 'video',
                ),
              );
            }
          }
        }
      }
    }

    state = state.copyWith(allMedia: mediaList, isLoading: false);
  }

  /// Permanently deletes a media file from disk and removes it from the library.
  Future<void> deleteTrack(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    // Remove from state
    state = state.copyWith(
      allMedia: state.allMedia.where((m) => m.path != path).toList(),
    );
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});
