import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/services/storage_service.dart';
import '../../../core/data/services/media_cache_service.dart';
import '../data/models/media_item.dart';
import '../data/repositories/library_repository.dart';
import '../../download/application/providers/download_settings_provider.dart';
import '../../playlist/application/playlist_provider.dart';
import '../../../core/utils/path_utils.dart';

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
  Timer? _saveDebouncer;

  @override
  LibraryState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    Future.microtask(() => _loadSavedPaths(prefs));
    

    ref.onDispose(() => _saveDebouncer?.cancel());

    return LibraryState();
  }

  void _scheduleSave() {
    _saveDebouncer?.cancel();
    _saveDebouncer = Timer(const Duration(seconds: 3), () {
      final repo = ref.read(libraryRepositoryProvider);
      repo.saveLibraryCache(state.allMedia);
    });
  }


  Future<void> _loadSavedPaths(SharedPreferences prefs) async {
    final musicPath = prefs.getString('music_folder') ?? await PathUtils.getMusicDefault();
    final videoPath = prefs.getString('video_folder') ?? await PathUtils.getVideoDefault();
    final lyricsPath = prefs.getString('lyrics_folder') ?? await PathUtils.getLyricsDefault();
    final cachePath = prefs.getString('cache_folder') ?? await PathUtils.getCacheDefault();

    state = state.copyWith(
      musicFolderPath: musicPath,
      videoFolderPath: videoPath,
      lyricsFolderPath: lyricsPath,
      cacheFolderPath: cachePath,
    );
    
    // Auto-sync with download settings on first load if they differ
    _syncToDownloadSettings(musicPath, videoPath, lyricsPath);
    
    final repo = ref.read(libraryRepositoryProvider);

    // 1. Instant Load from Persistent Cache (0 I/O Spike)
    final cachedMedia = await repo.loadLibraryCache();
    if (cachedMedia.isNotEmpty) {
      cachedMedia.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      state = state.copyWith(allMedia: cachedMedia);
      debugPrint('LibraryNotifier: Loaded ${cachedMedia.length} items from cache.');
    }

    // 2. Background Scan if Cache is Stale (12h Threshold)
    final lastScanStr = prefs.getString('last_library_scan');
    bool shouldScan = true;
    if (lastScanStr != null) {
      final lastScan = DateTime.tryParse(lastScanStr);
      if (lastScan != null && DateTime.now().difference(lastScan).inHours < 12) {
        shouldScan = false;
        debugPrint('LibraryNotifier: Cache is fresh (${DateTime.now().difference(lastScan).inHours}h old). Skipping auto-scan.');
      }
    }

    if (shouldScan) {
      Future.delayed(const Duration(seconds: 10), () {
         scanLibrary(isBackground: true);
      });
    } else {
      // Nothing to do
    }
  }

  Future<void> setMusicFolder(String path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('music_folder', path);
    state = state.copyWith(musicFolderPath: path);
    _syncToDownloadSettings(path, state.videoFolderPath, state.lyricsFolderPath);
    scanLibrary();
  }

  Future<void> setVideoFolder(String path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('video_folder', path);
    state = state.copyWith(videoFolderPath: path);
    _syncToDownloadSettings(state.musicFolderPath, path, state.lyricsFolderPath);
    scanLibrary();
  }

  Future<void> setLyricsFolder(String path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('lyrics_folder', path);
    state = state.copyWith(lyricsFolderPath: path);
    _syncToDownloadSettings(state.musicFolderPath, state.videoFolderPath, path);
  }

  void _syncToDownloadSettings(String? music, String? video, String? lyrics) {
    if (music == null && video == null && lyrics == null) return;
    
    final dlNotifier = ref.read(downloadSettingsProvider.notifier);
    final currentDlSettings = ref.read(downloadSettingsProvider).value;
    
    if (currentDlSettings != null) {
      final hasChanged = (music != null && currentDlSettings.musicOutputPath != music) ||
                         (video != null && currentDlSettings.videoOutputPath != video) ||
                         (lyrics != null && currentDlSettings.lyricsOutputPath != lyrics);

      if (!hasChanged) return;

      dlNotifier.saveSettings(currentDlSettings.copyWith(
        musicOutputPath: music ?? currentDlSettings.musicOutputPath,
        videoOutputPath: video ?? currentDlSettings.videoOutputPath,
        lyricsOutputPath: lyrics ?? currentDlSettings.lyricsOutputPath,
      ));
    }
  }

  Future<void> setCacheFolder(String path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('cache_folder', path);
    state = state.copyWith(cacheFolderPath: path);
  }

  Future<void> scanLibrary({bool isBackground = false}) async {
    if (!isBackground) state = state.copyWith(isLoading: true);
    final repo = ref.read(libraryRepositoryProvider);
    
    final mediaList = await repo.scanLibrary(
      musicFolderPath: state.musicFolderPath,
      videoFolderPath: state.videoFolderPath,
      existingItems: state.allMedia, // Provide existing items for differential scan
    );
 
    // Sort Alphabetically
    mediaList.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (listEquals(state.allMedia, mediaList)) {
      debugPrint('LibraryNotifier: No changes detected after scan.');
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(allMedia: mediaList, isLoading: false);

    // Save updated metadata to persistent cache
    await repo.saveLibraryCache(mediaList);

    // Auto-repair playlists with the newly scanned library items
    try {
      ref.read(playlistProvider.notifier).repairPlaylists(mediaList);
    } catch (_) {}

    // Update last scan time
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('last_library_scan', DateTime.now().toIso8601String());
  }

  Future<void> deleteTrack(MediaItem item) async {
    try {
      final String path = item.path;
      final String songId = item.id ?? path;
      
      // 1. Delete Main File
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Library removal: Deleted main file $path');
      }

      // 2. Delete Local Lyrics (.lrc in same folder)
      if (path.contains('.')) {
        final lrcPath = '${path.substring(0, path.lastIndexOf('.'))}.lrc';
        final lrcFile = File(lrcPath);
        if (await lrcFile.exists()) {
          await lrcFile.delete();
          debugPrint('Library removal: Deleted local lyrics $lrcPath');
        }
      }

      // 3. Delete Custom Lyrics Folder Entry
      if (state.lyricsFolderPath != null) {
        final fileName = item.path.startsWith('http') ? item.title : (path.contains(Platform.pathSeparator) ? path.split(Platform.pathSeparator).last : path);
        final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
        final customLrcPath = "${state.lyricsFolderPath}${Platform.pathSeparator}$baseName.lrc";
        final customLrcFile = File(customLrcPath);
        if (await customLrcFile.exists()) {
          await customLrcFile.delete();
          debugPrint('Library removal: Deleted custom lyrics $customLrcPath');
        }
      }

      // 4. Delete Cache Entries (Audio, JSON, Art, etc.)
      await ref.read(mediaCacheServiceProvider).removeFromCache(songId);

    } catch (e) {
        debugPrint('Error caching art in recently played: $e');
    }
    
    state = state.copyWith(
      allMedia: state.allMedia.where((m) => m.path != item.path).toList(),
    );
    
    // Sync cache after deletion (Debounced)
    _scheduleSave();
  }


  void addMediaItem(MediaItem item) {
    if (state.allMedia.any((m) => m.path == item.path)) return;
    
    final newList = [...state.allMedia, item];
    newList.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    state = state.copyWith(allMedia: newList);
    
    // Debounced persistent save to prevent "Write Data Leak" (multiple writes during batch download)
    _scheduleSave();
  }

  /// SOTA V13.6: Instant Awakening - Reload library from JSON cache
  Future<void> loadMetadataFromCache() async {
    final repo = ref.read(libraryRepositoryProvider);
    final cachedMedia = await repo.loadLibraryCache();
    if (cachedMedia.isNotEmpty) {
      cachedMedia.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      state = state.copyWith(allMedia: cachedMedia);
      debugPrint('LibraryNotifier: Instant Awakening! Loaded ${cachedMedia.length} items.');
    }
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});
