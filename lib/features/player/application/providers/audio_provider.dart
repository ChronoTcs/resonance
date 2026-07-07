import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../../home/presentation/providers/recently_played_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../../../library/application/library_provider.dart';

import '../../../../core/data/services/media_cache_service.dart';
import '../services/windows_system_media_service.dart';
import 'active_media_focus_provider.dart';
import '../services/playback_architecture_service.dart';
import '../services/queue_service.dart';
import '../../data/models/player_enums.dart';
import 'package:audio_session/audio_session.dart';
import '../audio_handler.dart';
import '../../../../core/data/services/stream_cache_tracker_service.dart';

// ── Extracted Services ────────────────────────────────────────────────────────
import '../states/audio_state.dart';
import '../../data/services/audio_persistence_service.dart';
import '../../data/services/audio_metadata_service.dart';
import '../services/stream_resolution_service.dart';

export '../states/audio_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AudioNotifier: Core Playback Domain
// Responsibilities: Player lifecycle, queue navigation, gapless playback,
//                   and anti-loop guard.
// All orthogonal concerns (Sync, Tracking, Maintenance, Restoration)
// are delegated to independent reactive services.
// ─────────────────────────────────────────────────────────────────────────────

class AudioNotifier extends Notifier<AudioState> {
  late Player _player;

  // ── Navigation guards ──────────────────────────────────────────────────────
  bool _isNavigating = false;
  final List<StreamSubscription> _subscriptions = [];
  DateTime? _lastCompletionTime;

  // ── Anti-loop guard (MUST stay here) ──────────────────────────────────────
  int _consecutiveErrorCount = 0;
  DateTime? _lastErrorTime;

  // ── Services ───────────────────────────────────────────────────────────────
  late QueueService _queue;
  late WindowsSystemMediaService _smtc;
  late AudioPersistenceService _persistence;
  late AudioMetadataService _metadata;
  late StreamResolutionService _resolver;

  @override
  AudioState build() {
    final audioHandler = ref.read(audioHandlerProvider);
    _player = audioHandler.player;

    audioHandler.onSkipToNext = () => next();
    audioHandler.onSkipToPrevious = () => skipToPrevious();

    _queue = ref.read(queueServiceProvider);
    _smtc = ref.read(windowsSystemMediaServiceProvider);
    _persistence = ref.read(audioPersistenceServiceProvider);
    _metadata = ref.read(audioMetadataServiceProvider);
    _resolver = ref.read(streamResolutionServiceProvider);

    // Cache path listener
    ref.listen(libraryProvider.select((s) => s.cacheFolderPath), (_, next) {
      ref.read(mediaCacheServiceProvider).setCustomPath(next);
      MpvConfigurator.applyCacheSettings(_player, next);
    });
    final initialPath = ref.read(libraryProvider).cacheFolderPath;
    ref.read(mediaCacheServiceProvider).setCustomPath(initialPath);
    MpvConfigurator.applyCacheSettings(_player, initialPath);

    if (isWindows) {
      _smtc.initialize(
        onPlay: play,
        onPause: pause,
        onNext: next,
        onPrevious: previous,
        onStop: stop,
      );
    }

    if (isAndroid) _initAudioSession();

    _initListeners();

    ref.onDispose(() {
      for (var sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
    });

    return AudioState();
  }

  // ── Public Accessors & Restoration Helpers (V17.0) ────────────────────────

  Player get player => _player;

  void setRestoredSettings({double? volume, double? speed, double? pitch}) {
    if (volume != null) {
      _player.setVolume(volume);
      state = state.copyWith(volume: volume);
    }
    if (speed != null) {
      _player.setRate(speed);
      state = state.copyWith(speed: speed);
    }
    if (pitch != null) {
      _player.setPitch(pow(2.0, pitch / 12.0).toDouble());
      state = state.copyWith(pitch: pitch);
    }
  }

  void restorePlaybackState({
    required MediaItem track,
    required List<MediaItem> queue,
    required int index,
    required int positionMs,
  }) {
    _queue.setQueue(queue, initialIndex: index);
    state = state.copyWith(
      queue: queue,
      currentIndex: index,
      currentTrack: track,
      position: Duration(milliseconds: positionMs),
    );
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('[AudioNotifier] Audio session config failed: $e');
    }
  }

  // ── Player Stream Listeners ────────────────────────────────────────────────

  void _initListeners() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        state = state.copyWith(isPlaying: playing);
        if (playing) _isNavigating = false;
        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          _metadata.onPlaybackStatusChanged(
            currentTrack: state.currentTrack,
            isPlaying: playing,
            position: state.position,
            duration: state.duration,
          );
        }
      }),

      _player.stream.position.listen((position) {
        state = state.copyWith(position: position);

        // V16.1: Persist position (debounced internally by persistence service)
        _persistence.savePosition(position.inMilliseconds);
        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          _metadata.onPositionChanged(
            position: position,
            duration: state.duration,
            currentTrack: state.currentTrack,
            isPlaying: state.isPlaying,
          );
        }
      }),

      _player.stream.duration.listen(
        (d) => state = state.copyWith(duration: d),
      ),
      _player.stream.volume.listen((v) => state = state.copyWith(volume: v)),

      _player.stream.completed.listen((completed) {
        if (!completed) return;
        final now = DateTime.now();
        if (_lastCompletionTime != null &&
            now.difference(_lastCompletionTime!).inMilliseconds < 800) {
          return;
        }
        _lastCompletionTime = now;
        final isNearEnd =
            state.position > Duration.zero &&
            state.duration > Duration.zero &&
            state.position >= state.duration - const Duration(seconds: 2);
        if (isNearEnd && ref.read(mediaFocusProvider) == MediaFocus.audio) {
          next(fromCompletion: true);
        }
      }),

      _player.stream.playlist.listen((playlist) {
        if (playlist.index == 1 &&
            ref.read(mediaFocusProvider) == MediaFocus.audio) {
          debugPrint('Gapless: Engine transitioned to pre-fetched track');
          next(fromCompletion: true);
        }
      }),

      // ── Anti-Loop Error Guard ─────────────────────────────────────────────
      _player.stream.error.listen((error) {
        final errStr = error.toString();
        if (errStr.contains('.lrc')) return;
        final now = DateTime.now();
        if (_lastErrorTime != null &&
            now.difference(_lastErrorTime!).inSeconds < 5) {
          _consecutiveErrorCount++;
        } else {
          _consecutiveErrorCount = 1;
        }
        _lastErrorTime = now;
        if (_consecutiveErrorCount >= 3) {
          debugPrint(
            '[AudioNotifier] CRITICAL: Stopping to prevent infinite error loop.',
          );
          state = state.copyWith(isPlaying: false, isLoading: false);
          _consecutiveErrorCount = 0;
          return;
        }
        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          Future.microtask(() => next(fromCompletion: true));
        }
      }),
    ]);
  }

  // ── Track Changed ──────────────────────────────────────────────────────────

  void _onTrackChanged(MediaItem track, int index) {
    state = state.copyWith(
      currentTrack: track,
      currentIndex: index,
      position: Duration.zero,
      duration: track.duration ?? Duration.zero,
    );
    if (index != -1) _queue.setCurrentIndex(index);
    _metadata.onTrackChanged(track, isPlaying: state.isPlaying);
    final songId = track.id ?? track.path;
    if (track.isStreaming) {
      ref.read(streamCacheTrackerServiceProvider).updateLastPlayed(songId);
    }
    _updateNextTrack();
    ref.read(recentlyPlayedProvider.notifier).addTrack(track);

    _persistence.savePlaybackState(
      trackJson: jsonEncode(track.toJson()),
      queueJson: state.queue.map((t) => jsonEncode(t.toJson())).toList(),
      index: index,
    );
  }

  // ── Playback Controls ──────────────────────────────────────────────────────

  Future<void> _playCurrentFromQueue(MediaItem track) async {
    ref.read(mediaFocusProvider.notifier).setAudioFocus();
    _smtc.setCallbacks(
      onPlay: play,
      onPause: pause,
      onNext: next,
      onPrevious: previous,
      onStop: stop,
    );
    final idx = state.queue.indexOf(track);
    await playTrack(track, index: idx);
  }

  // Public entry-point for YouTube / streaming tracks
  Future<void> playYouTubeTrack(MediaItem item, {int index = -1}) async {
    state = state.copyWith(isLoading: true, currentTrack: item);
    try {
      final resolvedPath = await _resolver.resolve(item);
      await playTrack(item.copyWith(path: resolvedPath), index: index);
    } catch (e) {
      debugPrint('[AudioNotifier] Stream resolution failed: $e');
      state = state.copyWith(isPlaying: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> playTrack(MediaItem item, {int index = -1}) async {
    if (state.queue.isEmpty ||
        (index == -1 &&
            !state.queue.any(
              (t) => (t.id ?? t.path) == (item.id ?? item.path),
            ))) {
      _queue.setQueue([item], initialIndex: 0);
      state = state.copyWith(queue: [item], currentIndex: 0);
      index = 0;
    }
    _onTrackChanged(item, index);
    try {
      await _player.open(_resolver.buildMedia(item.path), play: true);
      _consecutiveErrorCount = 0;
    } catch (e) {
      debugPrint('[AudioNotifier] CRITICAL: Error opening track: $e');
    }
    _updateNextTrack();
  }

  Future<void> playPlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
  }) async {
    if (items.isEmpty) return;
    _queue.setQueue(items, initialIndex: initialIndex);
    state = state.copyWith(queue: items, currentIndex: initialIndex);
    await _playCurrentFromQueue(items[initialIndex]);
    final ids = items
        .skip(initialIndex + 1)
        .where((e) => e.isStreaming)
        .take(3)
        .map((e) => e.id ?? e.path)
        .toList();
    if (ids.isNotEmpty) {
      ref.read(playbackArchitectureServiceProvider).predictiveFetch(ids);
    }
  }

  void addTrackToQueue(MediaItem item) {
    if (state.queue.isEmpty) {
      playPlaylist([item]);
    } else {
      final updatedQueue = [...state.queue, item];
      _queue.setQueue(updatedQueue, initialIndex: state.currentIndex);
      state = state.copyWith(queue: updatedQueue);
      _updateNextTrack();
    }
  }

  void preloadTracks(List<MediaItem> items) {
    final ids = items
        .where((e) => e.isStreaming)
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
    _queue.setQueue([], initialIndex: -1);
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
    if (_isNavigating) return;
    if (fromCompletion && ref.read(mediaFocusProvider) != MediaFocus.audio) {
      return stop();
    }
    if (state.queue.isEmpty) return stop();

    _isNavigating = true;
    final nextTrack = _queue.getNextTrack(
      state.loopMode,
      state.isShuffleEnabled,
      fromCompletion: fromCompletion,
    );

    if (nextTrack != null) {
      _playCurrentFromQueue(nextTrack).then((_) => _isNavigating = false);
    } else if (fromCompletion) {
      _isNavigating = false;
      pause();
      seek(Duration.zero);
    } else {
      _isNavigating = false;
    }
    state = state.copyWith(currentIndex: _queue.currentIndex);
    _updateNextTrack();
  }

  void previous() {
    final prev = _queue.getPreviousTrack();
    if (prev != null) _playCurrentFromQueue(prev);
    state = state.copyWith(currentIndex: _queue.currentIndex);
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

  void seek(Duration position) => _player.seek(position);
  void adjustVolume(double delta) =>
      setVolume((state.volume + delta).clamp(0.0, 100.0));
  void adjustPosition(Duration delta) {
    final raw = state.position + delta;
    final clamped = raw < Duration.zero
        ? Duration.zero
        : (raw > state.duration ? state.duration : raw);
    seek(clamped);
  }

  void setVolume(double v) {
    _player.setVolume(v);
    state = state.copyWith(volume: v);
    _persistence.saveVolume(v);
  }

  void setSpeed(double s) {
    _player.setRate(s);
    state = state.copyWith(speed: s);
    _persistence.saveSpeed(s);
  }

  void setPitch(double semitones) {
    _player.setPitch(pow(2.0, semitones / 12.0).toDouble());
    state = state.copyWith(pitch: semitones);
    _persistence.savePitch(semitones);
  }

  void setShuffle(bool enabled) => _setShuffleInternal(enabled);

  void toggleShuffle() {
    _setShuffleInternal(!state.isShuffleEnabled);
  }

  void _setShuffleInternal(bool enabled) {
    state = state.copyWith(isShuffleEnabled: enabled);
    if (enabled) {
      _queue.shuffleQueue();
    } else {
      _queue.setShuffle(false);
    }
    _persistence.saveShuffle(enabled);
    _updateNextTrack();
  }

  void cycleLoopMode() {
    final modes = LoopMode.values;
    final next = modes[(state.loopMode.index + 1) % modes.length];
    state = state.copyWith(loopMode: next);
    _persistence.saveLoopMode(next);
    _updateNextTrack();
  }

  void _updateNextTrack() {
    state = state.copyWith(
      nextTrack: _queue.peekNextTrack(state.loopMode, state.isShuffleEnabled),
    );
  }

  // ── Restore Defaults ───────────────────────────────────────────────────────

  Future<void> restoreToDefault() async {
    setVolume(100.0);
    setSpeed(1.0);
    setPitch(0.0);
  }
}

// ── Platform helpers ───────────────────────────────────────────────────────────

bool get isWindows => Platform.isWindows;
bool get isAndroid => Platform.isAndroid;

// ── Provider ──────────────────────────────────────────────────────────────────

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(() {
  return AudioNotifier();
});

/// Dedicated provider for the currently playing track metadata.
/// Provides reactive updates for UI components like MiniPlayer.
final currentTrackProvider = Provider<MediaItem?>((ref) {
  return ref.watch(audioProvider.select((s) => s.currentTrack));
});
