import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; // Added import
import 'package:smtc_windows/smtc_windows.dart';
import 'package:http/http.dart' as http;
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:window_manager/window_manager.dart';
import '../../../home/presentation/providers/recently_played_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../../../library/data/repositories/library_provider.dart';
import 'package:resonance_app/features/explore/presentation/providers/explore_provider.dart';
import '../../../../core/services/discord_rpc_service.dart';
import '../../../../core/services/media_cache_service.dart';

enum LoopMode { off, all, one }

class AudioState {
  final MediaItem? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final LoopMode loopMode;
  final bool isShuffleEnabled;
  final double volume;
  final double speed;
  final double pitch;
  final List<double> equalizerBands;
  final bool isEqualizerEnabled;
  final String equalizerPreset;
  final bool linkEqualizerSliders;
  final List<MediaItem> queue;
  final int currentIndex;
  final bool isLoading;

  AudioState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.loopMode = LoopMode.off,
    this.isShuffleEnabled = false,
    this.volume = 100.0,
    this.speed = 1.0,
    this.pitch = 0.0,
    this.equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.isEqualizerEnabled = false,
    this.equalizerPreset = 'Flat',
    this.linkEqualizerSliders = false,
    this.queue = const [],
    this.currentIndex = -1,
    this.isLoading = false,
  });

  AudioState copyWith({
    MediaItem? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    LoopMode? loopMode,
    bool? isShuffleEnabled,
    double? volume,
    double? speed,
    double? pitch,
    List<double>? equalizerBands,
    bool? isEqualizerEnabled,
    String? equalizerPreset,
    bool? linkEqualizerSliders,
    List<MediaItem>? queue,
    int? currentIndex,
    bool? isLoading,
  }) {
    return AudioState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      loopMode: loopMode ?? this.loopMode,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      equalizerBands: equalizerBands ?? this.equalizerBands,
      isEqualizerEnabled: isEqualizerEnabled ?? this.isEqualizerEnabled,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      linkEqualizerSliders: linkEqualizerSliders ?? this.linkEqualizerSliders,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AudioNotifier extends Notifier<AudioState> {
  late Player _player;
  SMTCWindows? _smtc;
  SharedPreferences? _prefs;

  List<String> _shuffleQueue = [];
  int _shuffleQueueIndex = -1;
  Timer? _saveTimer;

  void _schedulePrefSave(String key, dynamic value) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_prefs != null) {
        if (value is double) {
          _prefs!.setDouble(key, value);
        } else if (value is bool) {
          _prefs!.setBool(key, value);
        } else if (value is String) {
          _prefs!.setString(key, value);
        } else if (value is List<String>) {
          _prefs!.setStringList(key, value);
        }
      }
    });
  }

  void _applyEqualizer() {
    if (_player.platform is NativePlayer) {
      final np = _player.platform as NativePlayer;
      if (state.isEqualizerEnabled) {
        // Construct libmpv equalizer audio filter string
        // The 9 bands correspond to frequencies: 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
        final bands = state.equalizerBands;
        final freqs = [62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

        final filterParts = <String>[];
        for (int i = 0; i < bands.length; i++) {
          if (bands[i] != 0.0) {
            filterParts.add('superequalizer=${i + 1}b=${bands[i]}');
            // In libmpv, superequalizer handles multiple bands. But wait, `equalizer=f=freq:width_type=o:w=1:g=gain` is better.
          }
        }

        final afParts = <String>[];
        for (int i = 0; i < bands.length; i++) {
          if (bands[i] != 0.0) {
            afParts.add(
              'equalizer=f=${freqs[i]}:width_type=o:w=1:g=${bands[i]}',
            );
          }
        }
        final afString = afParts.isNotEmpty ? afParts.join(',') : '';
        np.setProperty('af', afString);
      } else {
        // Clear all filters
        np.setProperty('af', '');
      }
    }
  }


  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();

    // Load saved settings
    final volume = _prefs?.getDouble('audio_volume') ?? 100.0;
    final speed = _prefs?.getDouble('audio_speed') ?? 1.0;
    final pitch = _prefs?.getDouble('audio_pitch') ?? 0.0;
    final eqEnabled = _prefs?.getBool('audio_eq_enabled') ?? false;
    final eqPreset = _prefs?.getString('audio_eq_preset') ?? 'Flat';
    final eqLinked = _prefs?.getBool('audio_eq_linked') ?? false;

    List<double> eqBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final savedBands = _prefs?.getStringList('audio_eq_bands');
    if (savedBands != null && savedBands.length == 9) {
      eqBands = savedBands.map((s) => double.tryParse(s) ?? 0.0).toList();
    }

    // Apply loaded settings
    _player.setVolume(volume);
    _player.setRate(speed);
    _player.setPitch(pow(2.0, pitch / 12.0).toDouble());

    state = state.copyWith(
      volume: volume,
      speed: speed,
      pitch: pitch,
      isEqualizerEnabled: eqEnabled,
      equalizerPreset: eqPreset,
      linkEqualizerSliders: eqLinked,
      equalizerBands: eqBands,
    );
    _applyEqualizer();
  }

  Future<void> restoreToDefault() async {
    _player.setVolume(100.0);
    _player.setRate(1.0);
    _player.setPitch(1.0);

    const defaultBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    state = state.copyWith(
      volume: 100.0,
      speed: 1.0,
      pitch: 0.0,
      isEqualizerEnabled: false,
      equalizerPreset: 'Flat',
      linkEqualizerSliders: false,
      equalizerBands: defaultBands,
    );
    _applyEqualizer();

    if (_prefs != null) {
      await _prefs!.setDouble('audio_volume', 100.0);
      await _prefs!.setDouble('audio_speed', 1.0);
      await _prefs!.setDouble('audio_pitch', 0.0);
      await _prefs!.setBool('audio_eq_enabled', false);
      await _prefs!.setString('audio_eq_preset', 'Flat');
      await _prefs!.setBool('audio_eq_linked', false);
      await _prefs!.setStringList(
        'audio_eq_bands',
        defaultBands.map((e) => e.toString()).toList(),
      );
    }
  }

  @override
  AudioState build() {
    _player = Player(
      configuration: PlayerConfiguration(
        pitch: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
      ),
    );

    // Listen to cache folder changes to update MediaCacheService
    ref.listen(libraryProvider.select((s) => s.cacheFolderPath), (prev, next) {
      MediaCacheService.setCustomPath(next);
    });

    // Initialize with current value
    final initialCache = ref.read(libraryProvider).cacheFolderPath;
    MediaCacheService.setCustomPath(initialCache);

    if (Platform.isWindows) {
      try {
        _smtc = SMTCWindows(
          config: const SMTCConfig(
            playEnabled: true,
            pauseEnabled: true,
            nextEnabled: true,
            prevEnabled: true,
            stopEnabled: true,
            fastForwardEnabled: false,
            rewindEnabled: false,
          ),
        );

        _smtc?.buttonPressStream.listen((event) {
          switch (event) {
            case PressedButton.play:
              _player.play();
              break;
            case PressedButton.pause:
              _player.pause();
              break;
            case PressedButton.next:
              skipToNext();
              break;
            case PressedButton.previous:
              skipToPrevious();
              break;
            case PressedButton.stop:
              _player.stop();
              break;
            default:
              break;
          }
        });
      } catch (e) {
        print(
          "SMTC integration error (not supported or initialized earlier): $e",
        );
      }
    }

    _initListeners();
    _initPrefs();

    DiscordRpcService().initialize();

    ref.onDispose(() {
      _saveTimer?.cancel();
      _player.dispose();
      _smtc?.dispose();
      DiscordRpcService().dispose();
    });
    return AudioState();
  }

  void _initListeners() {
    _player.stream.playing.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
      if (Platform.isWindows) {
        _smtc?.setPlaybackStatus(
          isPlaying ? PlaybackStatus.Playing : PlaybackStatus.Paused,
        );
        _updateTaskbarThumbnail(isPlaying);
      }
      DiscordRpcService().updatePresence(
        state.currentTrack,
        state.position,
        state.duration,
        isPlaying,
      );
    });

    _player.stream.position.listen((position) {
      state = state.copyWith(position: position);
      if (Platform.isWindows) {
        _smtc?.setTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: state.duration.inMilliseconds,
            positionMs: position.inMilliseconds,
          ),
        );
      }
      DiscordRpcService().updatePresence(
        state.currentTrack,
        position,
        state.duration,
        state.isPlaying,
      );
    });

    _player.stream.duration.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    _player.stream.volume.listen((volume) {
      state = state.copyWith(volume: volume);
    });

    _player.stream.completed.listen((completed) {
      if (completed && state.loopMode != LoopMode.one) {
        skipToNext(fromCompletion: true);
      }
    });
  }

  Future<void> playTrack(MediaItem item) async {
    // Add track to recently played list
    ref.read(recentlyPlayedProvider.notifier).addTrack(item);

    state = state.copyWith(
      currentTrack: item,
      position: Duration.zero,
      duration: item.duration ?? Duration.zero,
      isPlaying: false, // Reset playing state during transition
    );

    // Defer system updates to prevent UI hiccups during loading
    Future.microtask(() async {
      try {
        // if (Platform.isWindows) {
        //   String? smtcThumbnailUrl;
          
        //   // Priority 1: Check Disk Cache (MediaCacheService)
        //   final cachePath = await MediaCacheService().getCachedArtPath(item.id ?? item.path);
        //   if (cachePath != null) {
        //     smtcThumbnailUrl = Uri.file(cachePath).toString();
        //   } 
        //   // Priority 2: Direct Local File (thumbnailUrl)
        //   else if (item.thumbnailUrl != null && !item.thumbnailUrl!.startsWith('http')) {
        //     smtcThumbnailUrl = Uri.file(item.thumbnailUrl!).toString();
        //   }
        if (Platform.isWindows) {
          String? smtcThumbnailUrl;
          
          // 1. LOGIKA THUMBNAIL (RAW PATH & HTTP MURNI)
          if (item.thumbnailUrl != null && item.thumbnailUrl!.startsWith('http')) {
            smtcThumbnailUrl = item.thumbnailUrl;
          } else if (item.id != null && item.id!.length == 11 && !item.id!.contains(r'\') && !item.id!.contains('/')) {
            smtcThumbnailUrl = 'https://i.ytimg.com/vi/${item.id}/hqdefault.jpg';
          } else {
            final cachePath = await MediaCacheService().getCachedArtPath(item.id ?? item.path);
            if (cachePath != null) {
              // PERBAIKAN: Gunakan Raw Path (C:\...), JANGAN gunakan Uri.file()
              smtcThumbnailUrl = cachePath; 
            } else if (item.thumbnailUrl != null && !item.thumbnailUrl!.startsWith('http')) {
              smtcThumbnailUrl = item.thumbnailUrl;
            }
          }

          // 2. PENGAMAN SMTC
          try {
            _smtc?.updateMetadata(
              MusicMetadata(
                title: item.title,
                albumArtist: item.artist ?? 'Unknown Artist',
                album: item.album ?? 'Unknown Album',
                artist: item.artist ?? 'Unknown Artist',
                thumbnail: smtcThumbnailUrl,
              ),
            );
          } catch (e) {
            print('SMTC Update Error: $e');
          }
          
          // 3. PENGAMAN WINDOWS (Mencegah PlatformException -1)
          try {
            if (Platform.isWindows) {
              await windowManager.setTitle('${item.title} - Resonance');
              await WindowsTaskbar.setThumbnailTooltip(
                '${item.artist ?? "Unknown Artist"} - ${item.title}',
              );
            }
          } catch (e) {
            print('Windows UI Update Error: $e');
          }
        }
      } catch (_) {}
    });

    try {
      // Explicitly stop previous playback to clear internal libmpv buffers
      // await _player.stop();

      if (item.path.startsWith('http')) {
        // Apply network optimizations for libmpv on Windows
        // if (_player.platform is NativePlayer) {
        //   final platform = _player.platform as NativePlayer;
        //   platform.setProperty('ytdl', 'no'); // Prevent mpv from using yt-dlp on direct stream URLs
        //   platform.setProperty('cache', 'yes');
        //   platform.setProperty('demuxer-max-bytes', '33554432'); // 32MB buffer
        // }

        await _player.open(Media(item.path), play: true);
      } else {
        await _player.open(Media(item.path), play: true);
      }
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  Future<void> playOnlineTrack(
    MediaItem displayItem,
    Future<String?> Function() fetchStreamUrl,
  ) async {
    final cacheService = MediaCacheService();
    final songId = displayItem.id ?? displayItem.path;

    // 1. Immediately check if Audio is already cached
    final cachedAudioPath = await cacheService.getCachedAudioPath(songId);
    
    // 2. Prepare the item with cached path if possible
    MediaItem trackToPlay = displayItem;
    if (cachedAudioPath != null) {
      print("Using cached audio: $cachedAudioPath");
      trackToPlay = displayItem.copyWith(path: cachedAudioPath);
    }

    // 3. Set UI state immediately
    state = state.copyWith(
      currentTrack: trackToPlay,
      isLoading: cachedAudioPath == null, // Only loading if not cached
      isPlaying: false,
      position: Duration.zero,
      duration: displayItem.duration ?? Duration.zero,
    );

    // 4. Background: Fetch Metadata & Thumbnails non-blockingly
    Future.microtask(() async {
      try {
        final cachedMeta = await cacheService.getCachedMetadata(songId);
        if (cachedMeta != null && cachedMeta.title != 'Unknown') {
          state = state.copyWith(currentTrack: state.currentTrack?.copyWith(
            title: cachedMeta.title,
            artist: cachedMeta.artist,
            album: cachedMeta.album,
          ));
        }

        // Fetch thumbnail if missing
        if (state.currentTrack?.albumArt == null) {
          final artBytes = await _fetchThumbnailBytes(displayItem.thumbnailUrl ?? songId);
          if (artBytes != null) {
            state = state.copyWith(currentTrack: state.currentTrack?.copyWith(albumArt: artBytes));
          }
        }
      } catch (_) {}
    });

    try {
      if (cachedAudioPath != null) {
        await playTrack(trackToPlay);
      } else {
        // Fetch stream URL and resolve
        final streamUrl = await fetchStreamUrl();
        if (streamUrl != null) {
          final playPath = await cacheService.getAudioPath(songId, streamUrl);
          final updatedItem = trackToPlay.copyWith(path: playPath);
          
          await playTrack(updatedItem);
          
          // Save metadata for next time in background
          Future.microtask(() => cacheService.saveMetadata(songId, updatedItem));
        }
      }
    } catch (e) {
      print("Error fetching online stream: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> playPlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
  }) async {
    if (items.isEmpty) return;

    state = state.copyWith(queue: items, currentIndex: initialIndex);

    final track = items[initialIndex];
    // Robust detection: URL path OR 11-char ID (YouTube)
    final isOnline = track.path.startsWith('http') || 
                    (track.id != null && track.id!.length == 11 && !track.id!.contains(Platform.pathSeparator));

    if (isOnline) {
      final ytService = ref.read(youtubeServiceProvider);
      await playOnlineTrack(
        track,
        () => ytService.getAudioStreamUrl(track.id ?? track.path),
      );
    } else {
      await playTrack(track);
    }
  }

  Future<Uint8List?> _fetchThumbnailBytes(String idOrUrl) async {
    try {
      // If it's just an ID, construct the URL. If it's already a URL, use it.
      String url = idOrUrl;
      if (!url.startsWith('http')) {
        url = 'https://i.ytimg.com/vi/$idOrUrl/hqdefault.jpg';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  void setVolume(double volume) {
    _player.setVolume(volume);
    _schedulePrefSave('audio_volume', volume);
    // Let the stream listener update the state.
  }

  void setSpeed(double speed) {
    _player.setRate(speed);
    state = state.copyWith(speed: speed);
    _schedulePrefSave('audio_speed', speed);
  }

  void setPitch(double semitones) {
    final multiplier = pow(2.0, semitones / 12.0).toDouble();
    _player.setPitch(multiplier);
    state = state.copyWith(pitch: semitones);
    _schedulePrefSave('audio_pitch', semitones);
  }

  void setEqualizerBand(int index, double value) {
    if (index >= 0 && index < state.equalizerBands.length) {
      final newBands = List<double>.from(state.equalizerBands);

      if (state.linkEqualizerSliders) {
        // Simple logic for linked sliders: decay neighboring bands
        double diff = value - newBands[index];
        newBands[index] = value;
        if (index > 0) {
          newBands[index - 1] = (newBands[index - 1] + (diff * 0.5)).clamp(
            -12.0,
            12.0,
          );
        }
        if (index < newBands.length - 1) {
          newBands[index + 1] = (newBands[index + 1] + (diff * 0.5)).clamp(
            -12.0,
            12.0,
          );
        }
      } else {
        newBands[index] = value;
      }

      state = state.copyWith(
        equalizerBands: newBands,
        equalizerPreset: 'Custom',
      );

      _schedulePrefSave(
        'audio_eq_bands',
        newBands.map((e) => e.toString()).toList(),
      );
      _schedulePrefSave('audio_eq_preset', 'Custom');
      _applyEqualizer();
    }
  }

  void toggleEqualizer(bool enabled) {
    state = state.copyWith(isEqualizerEnabled: enabled);
    _schedulePrefSave('audio_eq_enabled', enabled);
    _applyEqualizer();
  }

  void setEqualizerPreset(String preset) {
    List<double> newBands;
    switch (preset) {
      case 'Bass Boost':
        newBands = [6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        break;
      case 'Vocal':
        newBands = [-2.0, -1.0, 0.0, 2.0, 4.0, 4.0, 2.0, 0.0, -2.0];
        break;
      case 'Flat':
      default:
        newBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        break;
    }
    state = state.copyWith(equalizerPreset: preset, equalizerBands: newBands);

    _schedulePrefSave('audio_eq_preset', preset);
    _schedulePrefSave(
      'audio_eq_bands',
      newBands.map((e) => e.toString()).toList(),
    );
    _applyEqualizer();
  }

  void toggleLinkSliders(bool link) {
    state = state.copyWith(linkEqualizerSliders: link);
    _schedulePrefSave('audio_eq_linked', link);
  }

  void skipToNext({bool fromCompletion = false}) {
    // Check if we should auto-populate the queue for local tracks
    if (state.queue.isEmpty) {
      // Only auto-populate if we are ALREADY playing a local track
      // The user wants online songs to stop if no queue is set.
      final currentIsOnline =
          state.currentTrack?.id != null &&
          (state.currentTrack?.path.startsWith('http') ?? false);

      if (currentIsOnline) {
        if (fromCompletion) {
          _player.stop();
          return;
        }
      } else {
        final libraryState = ref.read(libraryProvider);
        final audioList = libraryState.allMedia
            .where((m) => m.type == 'audio')
            .toList();
        if (audioList.isEmpty) return;
        state = state.copyWith(queue: audioList);
      }
    }

    final queue = state.queue;
    if (queue.isEmpty) return;

    if (state.currentTrack == null) {
      _shuffleQueue.clear();
      _shuffleQueueIndex = -1;
      playPlaylist(queue, initialIndex: 0);
      return;
    }

    if (state.isShuffleEnabled) {
      if (_shuffleQueue.isEmpty) {
        _generateShuffleQueue(queue);
      }

      _shuffleQueueIndex++;

      if (_shuffleQueueIndex >= _shuffleQueue.length) {
        if (fromCompletion && state.loopMode == LoopMode.off) {
          _player.stop();
          return;
        }
        _generateShuffleQueue(queue, allowCurrentTrackFirst: false);
        _shuffleQueueIndex = 0;
      }

      final nextPath = _shuffleQueue[_shuffleQueueIndex];
      final nextTrackIndex = queue.indexWhere(
        (m) => m.path == nextPath || (m.id != null && m.id == nextPath),
      );
      if (nextTrackIndex != -1) {
        playPlaylist(queue, initialIndex: nextTrackIndex);
      }
    } else {
      int currentIndex = state.currentIndex;
      if (currentIndex == -1) {
        currentIndex = queue.indexWhere(
          (m) =>
              m.path == state.currentTrack!.path ||
              (m.id != null && m.id == state.currentTrack!.id),
        );
      }

      if (currentIndex == -1) {
        playPlaylist(queue, initialIndex: 0);
        return;
      }

      if (fromCompletion &&
          state.loopMode == LoopMode.off &&
          currentIndex == queue.length - 1) {
        _player.stop();
        return;
      }

      int nextIndex = (currentIndex + 1) % queue.length;
      playPlaylist(queue, initialIndex: nextIndex);
    }
  }

  void _generateShuffleQueue(
    List<MediaItem> allAudio, {
    bool allowCurrentTrackFirst = true,
  }) {
    _shuffleQueue = allAudio.map((m) => m.id ?? m.path).toList();
    _shuffleQueue.shuffle(Random());

    final currentId = state.currentTrack?.id ?? state.currentTrack?.path;

    // Ensure the current track is handled cleanly
    if (!allowCurrentTrackFirst &&
        currentId != null &&
        _shuffleQueue.isNotEmpty) {
      // Avoid replaying the same track immediately on shuffle regeneration
      if (_shuffleQueue[0] == currentId && _shuffleQueue.length > 1) {
        final temp = _shuffleQueue[0];
        _shuffleQueue[0] = _shuffleQueue[1];
        _shuffleQueue[1] = temp;
      }
    } else if (currentId != null && _shuffleQueue.contains(currentId)) {
      // Put the very current track at the beginning of the queue so back/next works properly
      _shuffleQueue.remove(currentId);
      _shuffleQueue.insert(0, currentId);
    }

    _shuffleQueueIndex = (currentId != null && allowCurrentTrackFirst) ? 0 : -1;
  }

  void skipToPrevious() {
    if (state.position.inSeconds > 3) {
      _player.seek(Duration.zero);
      return;
    }

    final queue = state.queue;
    if (queue.isEmpty) return;

    if (state.currentTrack == null) {
      playPlaylist(queue, initialIndex: 0);
      return;
    }

    if (state.isShuffleEnabled) {
      if (_shuffleQueue.isEmpty) {
        _generateShuffleQueue(queue);
      }

      _shuffleQueueIndex--;

      if (_shuffleQueueIndex < 0) {
        _shuffleQueueIndex = _shuffleQueue.length - 1;
      }

      final prevPath = _shuffleQueue[_shuffleQueueIndex];
      final prevTrackIndex = queue.indexWhere(
        (m) => m.path == prevPath || (m.id != null && m.id == prevPath),
      );
      if (prevTrackIndex != -1) {
        playPlaylist(queue, initialIndex: prevTrackIndex);
      }
    } else {
      int currentIndex = state.currentIndex;
      if (currentIndex == -1) {
        currentIndex = queue.indexWhere(
          (m) =>
              m.path == state.currentTrack!.path ||
              (m.id != null && m.id == state.currentTrack!.id),
        );
      }
      if (currentIndex == -1) {
        playPlaylist(queue, initialIndex: 0);
        return;
      }

      int prevIndex = (currentIndex - 1 + queue.length) % queue.length;
      playPlaylist(queue, initialIndex: prevIndex);
    }
  }

  void cycleLoopMode() {
    final LoopMode nextMode;
    switch (state.loopMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        _player.setPlaylistMode(PlaylistMode.loop);
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        _player.setPlaylistMode(PlaylistMode.single);
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        _player.setPlaylistMode(PlaylistMode.none);
        break;
    }
    state = state.copyWith(loopMode: nextMode);
  }

  void toggleShuffle() {
    final isShuffle = !state.isShuffleEnabled;
    state = state.copyWith(isShuffleEnabled: isShuffle);

    if (isShuffle) {
      final libraryState = ref.read(libraryProvider);
      final audioList = libraryState.allMedia
          .where((m) => m.type == 'audio')
          .toList();
      _generateShuffleQueue(audioList);
    } else {
      _shuffleQueue.clear();
      _shuffleQueueIndex = -1;
    }
  }

  void _updateTaskbarThumbnail(bool playing) {
    if (!Platform.isWindows) return;

    WindowsTaskbar.setThumbnailToolbar([
      ThumbnailToolbarButton(
        ThumbnailToolbarAssetIcon('assets/icons/previous.ico'),
        'Previous',
        () {
          skipToPrevious();
        },
      ),
      ThumbnailToolbarButton(
        playing
            ? ThumbnailToolbarAssetIcon('assets/icons/pause.ico')
            : ThumbnailToolbarAssetIcon('assets/icons/play.ico'),
        playing ? 'Pause' : 'Play',
        () {
          togglePlayPause();
        },
      ),
      ThumbnailToolbarButton(
        ThumbnailToolbarAssetIcon('assets/icons/next.ico'),
        'Next',
        () {
          skipToNext();
        },
      ),
    ]);
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(() {
  return AudioNotifier();
});
