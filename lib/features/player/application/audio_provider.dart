 import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/presentation/providers/recently_played_provider.dart';
import '../../library/data/models/media_item.dart';
import '../../library/application/library_provider.dart';
import '../../explore/data/services/youtube_service.dart';

import '../../../../core/services/discord_rpc_service.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../../../core/services/data_usage_service.dart';
import '../../../../core/services/storage_service.dart';
import 'windows_system_media_service.dart';
import 'active_media_focus_provider.dart';
import 'playback_architecture_service.dart';
import 'queue_service.dart';
import '../data/models/player_enums.dart';
import 'package:audio_session/audio_session.dart';
import 'audio_handler.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;

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
  final MediaItem? nextTrack;
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
    this.nextTrack,
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
    MediaItem? nextTrack,
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
      nextTrack: nextTrack ?? this.nextTrack,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AudioNotifier extends Notifier<AudioState> {
  late Player _player;
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  Timer? _eqApplyTimer;
  Timer? _usageTimer;
  int _lastBytesRead = 0;
  DateTime? _lastEqApplyTime;
  DateTime? _lastCompletionTime;
  bool _isNavigating = false;
  bool _isFetchingNext = false;
  final List<StreamSubscription> _subscriptions = [];

  late WindowsSystemMediaService _windowsService;
  late QueueService _queueService;

  @override
  AudioState build() {
    final audioHandler = ref.read(audioHandlerProvider);
    _player = audioHandler.player;

    // Link Android/System actions to app logic
    audioHandler.onSkipToNext = () => next();
    audioHandler.onSkipToPrevious = () => skipToPrevious();

    _prefs = ref.watch(sharedPreferencesProvider);
    _windowsService = ref.read(windowsSystemMediaServiceProvider);
    _queueService = ref.read(queueServiceProvider);

    ref.listen(libraryProvider.select((s) => s.cacheFolderPath), (prev, next) {
      ref.read(mediaCacheServiceProvider).setCustomPath(next);
    });
    ref.read(mediaCacheServiceProvider).setCustomPath(ref.read(libraryProvider).cacheFolderPath);

    if (Platform.isWindows) {
      _windowsService.initialize(
        onPlay: () => play(),
        onPause: () => pause(),
        onNext: () => next(),
        onPrevious: () => previous(),
        onStop: () => stop(),
      );
    }

    if (Platform.isAndroid) {
      _initAudioSession();
    }

    _initListeners();
    Future.microtask(() => _initPrefs(_prefs!));

    ref.read(discordRpcServiceProvider).initialize();

    ref.onDispose(() {
      _stopUsageTimer();
      _saveTimer?.cancel();
      _eqApplyTimer?.cancel();
      for (var sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
      // NOTE: Removed _player.dispose() and shared service disposals here 
      // because the player is now shared with ResonanceAudioHandler 
      // and managed at the app level. Disposing it here caused SIGABRT.
    });

    ref.listen(mediaFocusProvider, (prevFocus, nextFocus) {
      if (nextFocus == MediaFocus.audio && state.currentTrack != null) {
        _windowsService.updateMetadata(state.currentTrack, state.isPlaying);
        _windowsService.setCallbacks(
          onPlay: () => play(),
          onPause: () => pause(),
          onNext: () => next(),
          onPrevious: () => previous(),
          onStop: () => stop(),
        );
      }
    });

    return AudioState();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      print('AudioNotifier: Failed to configure audio session: $e');
    }
  }

  void _initListeners() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) async {
        state = state.copyWith(isPlaying: playing);
        
        if (playing) {
          _isNavigating = false;
        }

        final focus = ref.read(mediaFocusProvider);
        if (focus == MediaFocus.audio) {
          await _windowsService.updatePlaybackStatus(playing);
          _updatePresence();
        }
      }),

      _player.stream.position.listen((position) async {
        state = state.copyWith(position: position);
        
        // --- Proactive Queue Worker (Gapless Trigger) ---
        if (state.duration > Duration.zero && 
            state.duration.inSeconds > 20 && 
            !_isFetchingNext) {
          final remaining = state.duration - position;
          if (remaining.inSeconds <= 15 && remaining.inSeconds > 0) {
            _proactiveFetchNext();
          }
        }

        final focus = ref.read(mediaFocusProvider);
        if (focus == MediaFocus.audio) {
          await _windowsService.updateTimeline(position, state.duration);
          _updatePresence();
        }
      }),

      _player.stream.duration.listen((duration) {
        state = state.copyWith(duration: duration);
      }),

      _player.stream.volume.listen((volume) {
        state = state.copyWith(volume: volume);
      }),

      _player.stream.completed.listen((completed) {
        if (completed) {
          final now = DateTime.now();
          if (_lastCompletionTime != null && 
              now.difference(_lastCompletionTime!).inMilliseconds < 800) return;
          _lastCompletionTime = now;

          final isNearEnd = state.position > Duration.zero && 
                           state.duration > Duration.zero && 
                           state.position >= state.duration - const Duration(seconds: 2);
          
          if (isNearEnd) {
            // Trigger next() manually; QueueService now correctly returns null (stopping playback) 
            // if we've truly reached the end of the queue (considering shuffle and loop modes).
            final focus = ref.read(mediaFocusProvider);
            if (focus == MediaFocus.audio) {
              print('AudioNotifier: Track completed. Triggering manual next() fallback.');
              next(fromCompletion: true);
            } else {
              print('AudioNotifier: Track completed but focus is not audio. Staying silent.');
            }
          }
        }
      }),

      _player.stream.playlist.listen((playlist) {
        final index = playlist.index;
        // Gapless Management:
        // If index moves to 1, it means the native engine transitioned to the pre-fetched track.
        // We must trigger our next() logic to update state/metadata and pre-fetch the NEW next track.
        if (index == 1) {
          final focus = ref.read(mediaFocusProvider);
          if (focus == MediaFocus.audio) {
            print('Gapless: Engine transitioned to pre-fetched track at index 1');
            next(fromCompletion: true);
          }
        }
      }),

      _player.stream.error.listen((error) {
        final errorStr = error.toString();
        // Ignore non-fatal sidecar errors like lyrics (.lrc)
        if (errorStr.contains('.lrc')) {
          print('AudioNotifier: Ignoring non-fatal sidecar error: $errorStr');
          return;
        }

        print('Gapless Error Recovery: $error');
        // If a track in the playlist fails, skip to next to prevent deadlock
        final focus = ref.read(mediaFocusProvider);
        if (focus == MediaFocus.audio) {
          Future.microtask(() => next(fromCompletion: true));
        }
      }),
    ]);
  }

  void _onTrackChanged(MediaItem track, int index) {
    state = state.copyWith(
      currentTrack: track,
      currentIndex: index,
      position: Duration.zero,
      duration: track.duration ?? Duration.zero,
    );
    
    if (index != -1) {
      _queueService.setCurrentIndex(index);
    }
    _windowsService.updateMetadata(track, state.isPlaying);
    
    // Sync with Android MediaSession
    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.mediaItem.add(audio_svc.MediaItem(
      id: track.id ?? track.path,
      album: track.album ?? 'Unknown Album',
      title: track.title,
      artist: track.artist ?? 'Unknown Artist',
      duration: track.duration,
      artUri: track.thumbnailUrl != null 
          ? (track.thumbnailUrl!.startsWith('http') 
              ? Uri.parse(track.thumbnailUrl!) 
              : Uri.file(track.thumbnailUrl!))
          : null,
    ));

    _updatePresence();
    _updateNextTrack();
    ref.read(recentlyPlayedProvider.notifier).addTrack(track);
  }

  void _startUsageTimer() {
    _usageTimer?.cancel();
    _lastBytesRead = 0;
    _usageTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!state.isPlaying) return;
      
      try {
        final bytes = await (_player.platform as dynamic).getProperty('bytes-read');
        if (bytes != null && (bytes is int || bytes is double)) {
          final intBytes = bytes.toInt();
          final delta = intBytes - _lastBytesRead;
          if (delta > 0) {
            ref.read(dataUsageServiceProvider).addBytes(delta);
            _lastBytesRead = intBytes;
          }
        }
      } catch (_) {}
    });
  }

  void _stopUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  void _updatePresence() {
    ref.read(discordRpcServiceProvider).updatePresence(
          state.currentTrack,
          state.position,
          state.duration,
          state.isPlaying,
        );
  }

  Future<void> _initPrefs(SharedPreferences prefs) async {
    final volume = prefs.getDouble('audio_volume') ?? 100.0;
    final speed = prefs.getDouble('audio_speed') ?? 1.0;
    final pitch = prefs.getDouble('audio_pitch') ?? 0.0;

    _player.setVolume(volume);
    _player.setRate(speed);
    _player.setPitch(pow(2.0, pitch / 12.0).toDouble());

    final eqEnabled = prefs.getBool('audio_eq_enabled') ?? false;
    final eqPreset = prefs.getString('audio_eq_preset') ?? 'Flat';
    final eqLinked = prefs.getBool('audio_eq_linked') ?? false;
    List<double> eqBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final savedBands = prefs.getStringList('audio_eq_bands');
    if (savedBands != null && savedBands.length == 9) {
      eqBands = savedBands.map((s) => double.tryParse(s) ?? 0.0).toList();
    }

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

  void _schedulePrefSave(String key, dynamic value) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_prefs == null) return;
      if (value is double) _prefs!.setDouble(key, value);
      else if (value is bool) _prefs!.setBool(key, value);
      else if (value is String) _prefs!.setString(key, value);
      else if (value is List<String>) _prefs!.setStringList(key, value);
    });
  }

  Future<void> _playCurrentFromQueue(MediaItem track) async {
    // Set focus to audio when starting playback from queue
    ref.read(mediaFocusProvider.notifier).setAudioFocus();
    _windowsService.setCallbacks(
      onPlay: () => play(),
      onPause: () => pause(),
      onNext: () => next(),
      onPrevious: () => previous(),
      onStop: () => stop(),
    );

    final isOnline = _isOnline(track);

    final trackIndex = state.queue.indexOf(track);
    if (isOnline) {
      await playYouTubeTrack(track, index: trackIndex);
    } else {
      await playTrack(track, index: trackIndex);
    }
  }

  Future<void> playYouTubeTrack(MediaItem item, {int index = -1, int retryCount = 0}) async {
    if (!_isOnline(item)) {
      print("AudioNotifier: Falling back to playTrack for local-looking MediaItem: ${item.title}");
      return playTrack(item, index: index);
    }
    final ytService = ref.read(youtubeServiceProvider);
    await playOnlineTrack(
      item,
      () => ytService.getAudioStreamUrl(item.id ?? item.path),
      index: index,
      retryCount: retryCount,
    );
  }

  bool _isOnline(MediaItem item) {
    if (item.path.startsWith('http')) return true;
    
    // Check if ID looks like a YouTube ID (11 chars, alphanumeric/special)
    // and path IS NOT a local file path
    final hasYtId = item.id != null && 
                    item.id!.length == 11 && 
                    !item.id!.contains(Platform.pathSeparator);
    
    final isLocalPath = item.path.contains(Platform.pathSeparator) || 
                        item.path.startsWith('/') || 
                        (Platform.isWindows && item.path.contains(':'));
    
    return hasYtId && !isLocalPath;
  }

  Future<void> playOnlineTrack(
    MediaItem displayItem, 
    Future<String?> Function() fetchStreamUrl, 
    {int index = -1, int retryCount = 0}
  ) async {
    final cacheService = ref.read(mediaCacheServiceProvider);
    final archService = ref.read(playbackArchitectureServiceProvider);
    final songId = displayItem.id ?? displayItem.path;

    state = state.copyWith(isLoading: true, currentTrack: displayItem);

    try {
      final cachedAudioPath = await cacheService.getCachedAudioPath(songId);
      String? playPath = cachedAudioPath;

      if (playPath == null) {
        // Use architecture service (Cache + YoutubeExplode)
        final result = await archService.getStreamUrl(songId);
        if (result != null) {
          playPath = result;
          
          // Trigger persistent caching in background
          Future.microtask(() => cacheService.getAudioPath(songId, playPath!));
          Future.microtask(() => cacheService.saveMetadata(songId, displayItem));
        }
      }

      if (playPath == null) throw Exception("Stream URL not found");

      await playTrack(displayItem.copyWith(path: playPath), index: index);
    } catch (e) {
      print("Online Playback Error (Attempt ${retryCount + 1}): $e");
      
      if (retryCount < 0) { // Reduced retries for online tracks in gapless mode
        await Future.delayed(Duration(seconds: 1));
        return playOnlineTrack(displayItem, fetchStreamUrl, index: index, retryCount: retryCount + 1);
      }
      
      state = state.copyWith(isPlaying: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> playTrack(MediaItem item, {int index = -1}) async {
    // If we're playing a single track that isn't in our current queue,
    // establish a new single-item queue for it.
    if (state.queue.isEmpty || (index == -1 && !state.queue.any((t) => (t.id ?? t.path) == (item.id ?? item.path)))) {
      print('AudioNotifier: Standalone play detected, establishing new single-item queue');
      _queueService.setQueue([item], initialIndex: 0);
      state = state.copyWith(queue: [item], currentIndex: 0);
      index = 0;
    }

    _onTrackChanged(item, index);
    
    try {
      _startUsageTimer();
      // Use open(Media(...)) to clear previous playlist and start fresh
      await _player.open(Media(item.path), play: true);
    } catch (e) {
      print("Error opening track: $e");
    }
    
    _updateNextTrack();
  }

  Future<void> playPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    if (items.isEmpty) return;
    
    _queueService.setQueue(items, initialIndex: initialIndex);
    state = state.copyWith(
      queue: items,
      currentIndex: initialIndex,
    );

    final track = items[initialIndex];
    
    // Start playback of the first track
    await _playCurrentFromQueue(track);

    // Predictive: Pre-fetch URLs for the next 3 tracks in the background
    // Only prefetch ONLINE tracks to prevent hitting the YouTube API for local files
    final nextTrackIds = items
        .skip(initialIndex + 1)
        .where((e) => _isOnline(e))
        .take(3)
        .map((e) => e.id ?? e.path)
        .toList();
        
    if (nextTrackIds.isNotEmpty) {
      ref.read(playbackArchitectureServiceProvider).predictiveFetch(nextTrackIds);
    }
  }

  /// Triggers the predictive fetcher for a list of tracks (e.g. from search results).
  void preloadTracks(List<MediaItem> items) {
    final ids = items
        .where((e) => _isOnline(e))
        .map((e) => e.id ?? e.path)
        .toList();
    if (ids.isNotEmpty) {
      ref.read(playbackArchitectureServiceProvider).predictiveFetch(ids);
    }
  }

  void play() => _player.play();
  void pause() => _player.pause();
  void stop() => _player.stop();

  void stopAndClear() {
    _queueService.setQueue([], initialIndex: -1);
    state = state.copyWith(
      currentTrack: null,
      isPlaying: false,
      queue: [],
      currentIndex: -1,
      nextTrack: null,
      position: Duration.zero,
      duration: Duration.zero,
    );
    _player.stop();
  }
  void togglePlayPause() => state.isPlaying ? pause() : play();

  void next({bool fromCompletion = false}) {
    if (_isNavigating) {
      print('Navigation Guard: Blocked redundant next() call');
      return;
    }

    print('AudioNotifier.next: fromCompletion=$fromCompletion, currentIdx=${state.currentIndex}');
    
    if (fromCompletion) {
      final focus = ref.read(mediaFocusProvider);
      if (focus != MediaFocus.audio) {
        print('AudioNotifier.next: Focus is not audio, stopping auto-advance.');
        return stop();
      }
    }

    if (state.queue.isEmpty) {
      print('AudioNotifier.next: Queue is empty, stopping.');
      return stop();
    }

    _isNavigating = true;

    final nextTrack = _queueService.getNextTrack(
      state.loopMode,
      state.isShuffleEnabled,
      fromCompletion: fromCompletion,
    );

    if (nextTrack != null) {
      print('AudioNotifier.next: Found next track - ${nextTrack.title}');
      _playCurrentFromQueue(nextTrack).then((_) => _isNavigating = false);
    } else if (fromCompletion) {
      print('AudioNotifier.next: No more tracks, stopping.');
      _isNavigating = false;
      stop();
    } else {
      print('AudioNotifier.next: Manual skip at end of queue.');
      _isNavigating = false;
    }
    
    state = state.copyWith(
      currentIndex: _queueService.currentIndex,
    );
    _updateNextTrack();
  }

  void previous() {
    final prevTrack = _queueService.getPreviousTrack();
    if (prevTrack != null) {
      _playCurrentFromQueue(prevTrack);
    }
    
    state = state.copyWith(
      currentIndex: _queueService.currentIndex,
    );
    _updateNextTrack();
  }

  void skipToNext() => next();
  void skipToPrevious() {
    if (state.position.inSeconds > 3) {
      seek(Duration.zero);
    } else {
      previous();
    }
  }

  void adjustVolume(double delta) {
    final newVolume = (state.volume + delta).clamp(0.0, 100.0);
    setVolume(newVolume);
  }

  void adjustPosition(Duration delta) {
    final newPosition = state.position + delta;
    final clampedPosition = newPosition < Duration.zero 
        ? Duration.zero 
        : (newPosition > state.duration ? state.duration : newPosition);
    seek(clampedPosition);
  }

  void seek(Duration position) => _player.seek(position);

  void setVolume(double volume) {
    _player.setVolume(volume);
    _schedulePrefSave('audio_volume', volume);
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

  void toggleShuffle() {
    final newValue = !state.isShuffleEnabled;
    state = state.copyWith(isShuffleEnabled: newValue);
    if (newValue) {
      _queueService.shuffleQueue();
    } else {
      _queueService.setShuffle(false);
    }
    _updateNextTrack();
  }

  void cycleLoopMode() {
    final modes = LoopMode.values;
    final nextMode = modes[(state.loopMode.index + 1) % modes.length];
    state = state.copyWith(loopMode: nextMode);
    _updateNextTrack();
  }

  void _updateNextTrack() {
    final next = _queueService.peekNextTrack(state.loopMode, state.isShuffleEnabled);
    state = state.copyWith(nextTrack: next);
  }

  void toggleEqualizer(bool enabled) {
    state = state.copyWith(isEqualizerEnabled: enabled);
    _schedulePrefSave('audio_eq_enabled', enabled);
    _applyEqualizer();
  }

  void setEqualizerBand(int index, double value) {
    if (index < 0 || index >= state.equalizerBands.length) return;
    
    final newBands = List<double>.from(state.equalizerBands);
    final double diff = value - newBands[index];
    newBands[index] = value;
    
    if (state.linkEqualizerSliders) {
      // 1st Neighbors: 50% effect
      if (index > 0) newBands[index - 1] = (newBands[index - 1] + diff * 0.5).clamp(-12.0, 12.0);
      if (index < newBands.length - 1) newBands[index + 1] = (newBands[index + 1] + diff * 0.5).clamp(-12.0, 12.0);
      
      // 2nd Neighbors: 25% effect
      if (index > 1) newBands[index - 2] = (newBands[index - 2] + diff * 0.25).clamp(-12.0, 12.0);
      if (index < newBands.length - 2) newBands[index + 2] = (newBands[index + 2] + diff * 0.25).clamp(-12.0, 12.0);
    }
    
    state = state.copyWith(
      equalizerBands: newBands,
      equalizerPreset: 'Custom',
    );

    _schedulePrefSave('audio_eq_bands', newBands.map((e) => e.toString()).toList());
    _schedulePrefSave('audio_eq_preset', 'Custom');
    _applyEqualizerThrottled();
  }

  void _applyEqualizerThrottled() {
    final now = DateTime.now();
    const throttleDuration = Duration(milliseconds: 200);

    // Cancel any pending trailing update
    _eqApplyTimer?.cancel();

    if (_lastEqApplyTime == null || now.difference(_lastEqApplyTime!) > throttleDuration) {
      // Leading: Apply immediately
      _applyEqualizer();
      _lastEqApplyTime = now;
    } else {
      // Trailing: Schedule for the future to catch the final position
      _eqApplyTimer = Timer(throttleDuration - now.difference(_lastEqApplyTime!), () {
        _applyEqualizer();
        _lastEqApplyTime = DateTime.now();
      });
    }
  }

  void setEqualizerPreset(String preset) {
    List<double> newBands;
    switch (preset) {
      case 'Bass Boost': newBands = [6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]; break;
      case 'Vocal': newBands = [-2.0, -1.0, 0.0, 2.0, 4.0, 4.0, 2.0, 0.0, -2.0]; break;
      default: newBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]; break;
    }
    
    state = state.copyWith(equalizerPreset: preset, equalizerBands: newBands);
    _schedulePrefSave('audio_eq_preset', preset);
    _schedulePrefSave('audio_eq_bands', newBands.map((e) => e.toString()).toList());
    _applyEqualizer();
  }

  void toggleLinkSliders(bool link) {
    state = state.copyWith(linkEqualizerSliders: link);
    _schedulePrefSave('audio_eq_linked', link);
  }

  void _proactiveFetchNext() async {
    final nextTrack = _queueService.peekNextTrack(state.loopMode, state.isShuffleEnabled);
    if (nextTrack == null || _isFetchingNext || !_isOnline(nextTrack)) return;

    _isFetchingNext = true;
    print('Gapless: Proactively fetching next track - ${nextTrack.title}');

    try {
      final archService = ref.read(playbackArchitectureServiceProvider);
      final songId = nextTrack.id ?? nextTrack.path;
      final result = await archService.getStreamUrl(songId);
      
      if (result != null) {
        print('Gapless: Appending next track to media_kit playlist');
        await _player.add(Media(result));
      }
    } catch (e) {
      print('Gapless: Proactive fetch failed: $e');
    } finally {
      // Small cooldown to prevent rapid-fire fetches
      await Future.delayed(const Duration(seconds: 10));
      _isFetchingNext = false;
    }
  }

  void _applyEqualizer() {
    _lastEqApplyTime = DateTime.now();
    if (_player.platform is NativePlayer) {
      final np = _player.platform as NativePlayer;
      if (state.isEqualizerEnabled) {
        final freqs = [62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
        final afParts = <String>[];
        for (int i = 0; i < state.equalizerBands.length; i++) {
          if (state.equalizerBands[i] != 0.0) {
            afParts.add('equalizer=f=${freqs[i]}:width_type=o:w=1:g=${state.equalizerBands[i]}');
          }
        }
        final filterString = afParts.join(',');
        debugPrint('AudioNotifier: Applying Equalizer filter: $filterString');
        np.setProperty('af', filterString);
      } else {
        debugPrint('AudioNotifier: Clearing Equalizer filters');
        np.setProperty('af', '');
      }
    }
  }

  Future<void> restoreToDefault() async {
    setVolume(100.0);
    setSpeed(1.0);
    setPitch(0.0);
    toggleEqualizer(false);
    setEqualizerPreset('Flat');
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(() {
  return AudioNotifier();
});
