import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import
import 'package:smtc_windows/smtc_windows.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import '../../../library/data/repositories/library_provider.dart';
import '../../../library/data/models/media_item.dart';

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
    );
  }
}

class AudioNotifier extends Notifier<AudioState> {
  late Player _player;
  SMTCWindows? _smtc;
  HttpServer? _artServer;
  String? _artServerUrl;
  SharedPreferences? _prefs;

  Future<void> _startArtServer() async {
    if (_artServer != null) return;
    try {
      _artServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _artServerUrl = 'http://127.0.0.1:${_artServer!.port}/art.jpg';
      _artServer!.listen((HttpRequest request) {
        if (request.uri.path == '/art.jpg') {
          final file = File('${Directory.systemTemp.path}\\resonance_art.jpg');
          if (file.existsSync()) {
            request.response.headers.contentType = ContentType('image', 'jpeg');
            file.openRead().pipe(request.response);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.close();
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });
    } catch (_) {}
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
    _player.setPitch(pitch);

    state = state.copyWith(
      volume: volume,
      speed: speed,
      pitch: pitch,
      isEqualizerEnabled: eqEnabled,
      equalizerPreset: eqPreset,
      linkEqualizerSliders: eqLinked,
      equalizerBands: eqBands,
    );
  }

  Future<void> restoreToDefault() async {
    _player.setVolume(100.0);
    _player.setRate(1.0);
    _player.setPitch(0.0);

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
    _player = Player();

    if (Platform.isWindows) {
      _startArtServer();
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

    ref.onDispose(() {
      _player.dispose();
      _smtc?.dispose();
      _artServer?.close(force: true);
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
    });

    _player.stream.duration.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    _player.stream.volume.listen((volume) {
      state = state.copyWith(volume: volume);
    });

    _player.stream.completed.listen((completed) {
      // LoopMode.all not naturally handled because we feed Media separately,
      // LoopMode.one is handled natively by media_kit's PlaylistMode.single
      if (completed && state.loopMode != LoopMode.one) {
        skipToNext();
      }
    });
  }

  Future<void> playTrack(MediaItem item) async {
    state = state.copyWith(currentTrack: item);
    if (Platform.isWindows) {
      try {
        String? thumbnailPath;
        if (item.albumArt != null) {
          final file = File('${Directory.systemTemp.path}\\resonance_art.jpg');
          await file.writeAsBytes(item.albumArt!);
          thumbnailPath =
              _artServerUrl; // Local HTTP Server binds UWP Uri cleanly
        }

        _smtc?.updateMetadata(
          MusicMetadata(
            title: item.title,
            albumArtist: item.artist ?? 'Unknown Artist',
            album: item.album ?? 'Resonance',
            artist:
                'Resonance', // The 'artist' property in Windows SMTC actually determines the Top-Level App Name display instead of 'albumArtist'
            thumbnail:
                thumbnailPath, // Passing null instead of empty string avoids native Unwrap panics.
          ),
        );
        WindowsTaskbar.setWindowTitle('${item.title} - Resonance');
        WindowsTaskbar.setThumbnailTooltip(
          '${item.artist ?? "Unknown Artist"} - ${item.title}',
        );
      } catch (_) {}
    }
    try {
      await _player.open(Media(item.path));
      _player.play();
    } catch (e) {
      print("Error loading audio: $e");
    }
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
    _prefs?.setDouble('audio_volume', volume);
    // Let the stream listener update the state.
  }

  void setSpeed(double speed) {
    _player.setRate(speed);
    state = state.copyWith(speed: speed);
    _prefs?.setDouble('audio_speed', speed);
  }

  void setPitch(double pitch) {
    _player.setPitch(pitch);
    state = state.copyWith(pitch: pitch);
    _prefs?.setDouble('audio_pitch', pitch);
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
        state = state.copyWith(
          equalizerBands: newBands,
          equalizerPreset: 'Custom',
        );
        state = state.copyWith(
          equalizerBands: newBands,
          equalizerPreset: 'Custom',
        );
      }
      _prefs?.setStringList(
        'audio_eq_bands',
        newBands.map((e) => e.toString()).toList(),
      );
      _prefs?.setString('audio_eq_preset', 'Custom');
    }
  }

  void toggleEqualizer(bool enabled) {
    state = state.copyWith(isEqualizerEnabled: enabled);
    _prefs?.setBool('audio_eq_enabled', enabled);
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

    _prefs?.setString('audio_eq_preset', preset);
    _prefs?.setStringList(
      'audio_eq_bands',
      newBands.map((e) => e.toString()).toList(),
    );
  }

  void toggleLinkSliders(bool link) {
    state = state.copyWith(linkEqualizerSliders: link);
    _prefs?.setBool('audio_eq_linked', link);
  }

  void skipToNext() {
    final libraryState = ref.read(libraryProvider);
    final audioList = libraryState.allMedia
        .where((m) => m.type == 'audio')
        .toList();

    if (audioList.isEmpty) return;

    if (state.currentTrack == null) {
      playTrack(audioList.first);
      return;
    }

    int currentIndex = audioList.indexWhere(
      (m) => m.path == state.currentTrack!.path,
    );
    if (currentIndex == -1) {
      playTrack(audioList.first);
      return;
    }

    int nextIndex;
    if (state.isShuffleEnabled) {
      nextIndex = Random().nextInt(audioList.length);
    } else {
      nextIndex = (currentIndex + 1) % audioList.length;
    }

    playTrack(audioList[nextIndex]);
  }

  void skipToPrevious() {
    if (state.position.inSeconds > 3) {
      _player.seek(Duration.zero);
      return;
    }

    final libraryState = ref.read(libraryProvider);
    final audioList = libraryState.allMedia
        .where((m) => m.type == 'audio')
        .toList();

    if (audioList.isEmpty) return;

    if (state.currentTrack == null) {
      playTrack(audioList.first);
      return;
    }

    int currentIndex = audioList.indexWhere(
      (m) => m.path == state.currentTrack!.path,
    );
    if (currentIndex == -1) {
      playTrack(audioList.first);
      return;
    }

    int prevIndex;
    if (state.isShuffleEnabled) {
      prevIndex = Random().nextInt(audioList.length);
    } else {
      prevIndex = (currentIndex - 1 + audioList.length) % audioList.length;
    }

    playTrack(audioList[prevIndex]);
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
    // Note: To properly shuffle, we will need to randomize the playback queue later.
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
