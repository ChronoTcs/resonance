import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/path_utils.dart';
import '../../../library/application/library_provider.dart';

class DownloadSettings {
  final String musicOutputPath;
  final String videoOutputPath;
  final String lyricsOutputPath;
  final int maxConcurrent;
  final int maxRetries;
  final int connectionTimeout; // seconds
  final int fragmentsPerDownload;
  final String audioQuality; // "128" | "192" | "320"
  final String defaultSource; // "ytmusic" | "youtube"

  const DownloadSettings({
    this.musicOutputPath = '',
    this.videoOutputPath = '',
    this.lyricsOutputPath = '',
    this.maxConcurrent = 2,
    this.maxRetries = 3,
    this.connectionTimeout = 30,
    this.fragmentsPerDownload = 4,
    this.audioQuality = '192',
    this.defaultSource = 'ytmusic',
  });

  DownloadSettings copyWith({
    String? musicOutputPath,
    String? videoOutputPath,
    String? lyricsOutputPath,
    int? maxConcurrent,
    int? maxRetries,
    int? connectionTimeout,
    int? fragmentsPerDownload,
    String? audioQuality,
    String? defaultSource,
  }) {
    return DownloadSettings(
      musicOutputPath: musicOutputPath ?? this.musicOutputPath,
      videoOutputPath: videoOutputPath ?? this.videoOutputPath,
      lyricsOutputPath: lyricsOutputPath ?? this.lyricsOutputPath,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      maxRetries: maxRetries ?? this.maxRetries,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      fragmentsPerDownload: fragmentsPerDownload ?? this.fragmentsPerDownload,
      audioQuality: audioQuality ?? this.audioQuality,
      defaultSource: defaultSource ?? this.defaultSource,
    );
  }
}

final downloadSettingsProvider =
    AsyncNotifierProvider<DownloadSettingsNotifier, DownloadSettings>(
      DownloadSettingsNotifier.new,
    );

class DownloadSettingsNotifier extends AsyncNotifier<DownloadSettings> {
  static const _kMusicPath = 'dl_music_path';
  static const _kVideoPath = 'dl_video_path';
  static const _kLyricsPath = 'dl_lyrics_path';
  static const _kMaxConcurrent = 'dl_max_concurrent';
  static const _kMaxRetries = 'dl_max_retries';
  static const _kTimeout = 'dl_timeout';
  static const _kFragments = 'dl_fragments';
  static const _kQuality = 'dl_quality';
  static const _kSource = 'dl_source';

  @override
  Future<DownloadSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultMusic = await PathUtils.getMusicDefault();
    final defaultVideo = await PathUtils.getVideoDefault();
    final defaultLyrics = await PathUtils.getLyricsDefault();

    return DownloadSettings(
      musicOutputPath: prefs.getString(_kMusicPath) ?? defaultMusic,
      videoOutputPath: prefs.getString(_kVideoPath) ?? defaultVideo,
      lyricsOutputPath: prefs.getString(_kLyricsPath) ?? defaultLyrics,
      maxConcurrent: prefs.getInt(_kMaxConcurrent) ?? 2,
      maxRetries: prefs.getInt(_kMaxRetries) ?? 3,
      connectionTimeout: prefs.getInt(_kTimeout) ?? 30,
      fragmentsPerDownload: prefs.getInt(_kFragments) ?? 4,
      audioQuality: prefs.getString(_kQuality) ?? '192',
      defaultSource: prefs.getString(_kSource) ?? 'ytmusic',
    );
  }

  Future<void> saveSettings(DownloadSettings settings) async {
    state = AsyncValue.data(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMusicPath, settings.musicOutputPath);
    await prefs.setString(_kVideoPath, settings.videoOutputPath);
    await prefs.setString(_kLyricsPath, settings.lyricsOutputPath);
    // ... rest of the settings
    await prefs.setInt(_kMaxConcurrent, settings.maxConcurrent);
    await prefs.setInt(_kMaxRetries, settings.maxRetries);
    await prefs.setInt(_kTimeout, settings.connectionTimeout);
    await prefs.setInt(_kFragments, settings.fragmentsPerDownload);
    await prefs.setString(_kQuality, settings.audioQuality);
    await prefs.setString(_kSource, settings.defaultSource);
    
    // Sync to Library
    _syncToLibrary(settings);
  }

  void _syncToLibrary(DownloadSettings settings) {
    final library = ref.read(libraryProvider.notifier);
    final libraryState = ref.read(libraryProvider);
    
    if (libraryState.musicFolderPath != settings.musicOutputPath) {
      library.setMusicFolder(settings.musicOutputPath);
    }
    if (libraryState.videoFolderPath != settings.videoOutputPath) {
      library.setVideoFolder(settings.videoOutputPath);
    }
    if (libraryState.lyricsFolderPath != settings.lyricsOutputPath) {
      library.setLyricsFolder(settings.lyricsOutputPath);
    }
  }
}
