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
import '../../../../core/exceptions/offline_exception.dart';

import '../services/windows_system_media_service.dart';
import 'active_media_focus_provider.dart';
import '../services/playback_architecture_service.dart';
import '../services/queue_service.dart';
import '../../data/models/player_enums.dart';
import 'package:audio_session/audio_session.dart';
import '../audio_handler.dart';
import '../../../../core/data/services/stream_cache_tracker_service.dart';

import '../services/playback_engine_service.dart';
import '../../../settings/application/notification_provider.dart';

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

  // ── Services ───────────────────────────────────────────────────────────────
  late QueueService _queue;
  late WindowsSystemMediaService _smtc;
  late AudioPersistenceService _persistence;
  late AudioMetadataService _metadata;
  late StreamResolutionService _resolver;
  PlaybackEngineService get _engine => ref.read(playbackEngineServiceProvider);

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
      _engine.configureCache(_player, next);
    });
    final initialPath = ref.read(libraryProvider).cacheFolderPath;
    _engine.configureCache(_player, initialPath);

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
    _metadata.onTrackChanged(track, isPlaying: false);
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
        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          next(fromCompletion: true);
        }
      }),

      // ── Anti-Loop Error Guard ─────────────────────────────────────────────
      _player.stream.error.listen((error) {
        debugPrint('[AudioPlayer] [ERROR] Streaming / Playback error: $error');
        final currentId = state.currentTrack?.id ?? state.currentTrack?.path;
        if (currentId != null) {
          ref.read(playbackArchitectureServiceProvider).invalidate(currentId);
        }

        final shouldStop = _engine.handlePlaybackError(error);
        if (shouldStop) {
          state = state.copyWith(isPlaying: false, isLoading: false);
          return;
        }

        // Transparent 403 self-heal: re-resolve same track before skipping
        final errStr = error.toString().toLowerCase();
        final is403 = errStr.contains('403') || errStr.contains('forbidden') || errStr.contains('expired');
        if (is403 && currentId != null && (state.currentTrack?.isStreaming ?? false)) {
          debugPrint('[AudioPlayer] 403 detected — attempting self-heal re-resolve for $currentId');
          Future.microtask(() async {
            try {
              final url = await ref.read(playbackArchitectureServiceProvider)
                  .getStreamUrl(currentId, forceRefresh: true);
              if (url != null) {
                debugPrint('[AudioPlayer] Self-heal success — resuming $currentId');
                await _player.open(Media(url));
                return;
              }
            } catch (_) {}
            debugPrint('[AudioPlayer] Self-heal failed — skipping to next');
            if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
              next(fromCompletion: true);
            }
          });
          return;
        }

        ref
            .read(notificationProvider.notifier)
            .showNotification(
              'Playback Error',
              'Streaming / Playback error: $error',
              isError: true,
            );
        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          Future.microtask(() => next(fromCompletion: true));
        }
      }),
    ]);
  }

  // ── Track Changed ──────────────────────────────────────────────────────────

  void _onTrackChanged(MediaItem track, int index) {
    final cleanTrack = track.copyWith(lyricsOffset: Duration.zero);
    state = state.copyWith(
      currentTrack: cleanTrack,
      currentIndex: index,
      position: Duration.zero,
      duration: cleanTrack.duration ?? Duration.zero,
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

  /// Updates current track metadata in state without re-triggering playback setup
  void updateCurrentTrack(MediaItem updatedTrack) {
    if (state.currentTrack?.id == updatedTrack.id ||
        (state.currentTrack?.title == updatedTrack.title && state.currentTrack?.artist == updatedTrack.artist)) {
      state = state.copyWith(currentTrack: updatedTrack);
    }
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
    // If playing a new standalone track (index == -1), reset queue immediately to avoid metadata desync
    final existingIndex = state.queue.indexWhere(
      (t) => (t.id ?? t.path) == (item.id ?? item.path),
    );
    if (index == -1 && existingIndex == -1) {
      _queue.setQueue([item], initialIndex: 0);
      state = state.copyWith(
        isLoading: true,
        currentTrack: item,
        queue: [item],
        currentIndex: 0,
      );
      index = 0;
    } else {
      state = state.copyWith(isLoading: true, currentTrack: item);
    }

    try {
      final resolvedPath = await _resolver.resolve(item);
      await playTrack(item.copyWith(path: resolvedPath), index: index);
    } on OfflinePlaybackException {
      debugPrint('[AudioNotifier] Offline — skipping to next local track');
      state = state.copyWith(isPlaying: false, isLoading: false);
      ref.read(notificationProvider.notifier).showNotification(
        'You\'re Offline',
        'Skipping to next local track. Download tracks to play offline.',
      );
      // Advance queue without re-triggering stream resolution
      if (state.queue.length > 1) Future.microtask(() => next());
    } catch (e) {
      debugPrint('[AudioNotifier] Stream resolution failed: $e');
      state = state.copyWith(isPlaying: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> playTrack(MediaItem item, {int index = -1}) async {
    final targetId = item.id ?? item.path;
    if (state.queue.isEmpty ||
        (index == -1 &&
            !state.queue.any((t) => (t.id ?? t.path) == targetId))) {
      _queue.setQueue([item], initialIndex: 0);
      state = state.copyWith(queue: [item], currentIndex: 0);
      index = 0;
    } else if (index == -1) {
      index = state.queue.indexWhere((t) => (t.id ?? t.path) == targetId);
    }

    MediaItem trackToPlay = item;
    if (item.isStreaming &&
        !item.path.startsWith('http') &&
        !item.path.contains('/') &&
        !item.path.contains('\\')) {
      state = state.copyWith(isLoading: true, currentTrack: item);
      try {
        final resolvedPath = await _resolver.resolve(item);
        trackToPlay = item.copyWith(path: resolvedPath);
      } on OfflinePlaybackException {
        debugPrint('[AudioNotifier] Offline — skipping to next local track (playTrack)');
        state = state.copyWith(isPlaying: false, isLoading: false);
        ref.read(notificationProvider.notifier).showNotification(
          'You\'re Offline',
          'Skipping to next local track. Download tracks to play offline.',
        );
        if (state.queue.length > 1) Future.microtask(() => next());
        return;
      } catch (e) {
        debugPrint('[AudioNotifier] Stream resolution failed in playTrack: $e');
        state = state.copyWith(isPlaying: false, isLoading: false);
        return;
      }
    }

    // pass original item (not resolved-URL trackToPlay) so state.currentTrack
    // keeps the video-ID path. Prevents orchestrator from seeing a fake "track change"
    // when the URL is resolved, which would re-trigger a duplicate radio fetch.
    _onTrackChanged(item, index);
    state = state.copyWith(isLoading: true);
    try {
      await _player.open(_resolver.buildMedia(trackToPlay.path, player: _player), play: true);
      _engine.resetErrorGuard();
    } catch (e) {
      debugPrint('[AudioNotifier] CRITICAL: Error opening track: $e');
    } finally {
      state = state.copyWith(isLoading: false);
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
    final itemId = item.id ?? item.path;
    final exists = state.queue.any((t) => (t.id ?? t.path) == itemId);
    if (exists) return; // Queue deduplication guard

    if (state.queue.isEmpty) {
      playPlaylist([item]);
    } else {
      // appendTrack preserves cursor — avoids setQueue cursor reset
      _queue.appendTrack(item);
      state = state.copyWith(queue: [...state.queue, item]);
      _updateNextTrack();
    }
  }

  /// Batch-appends tracks to queue. Fires _updateNextTrack once — not once per track.
  void addTracksToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    // Deduplicate incoming tracks against current queue and within the batch
    final existingIds = state.queue.map((t) => t.id ?? t.path).toSet();
    final deduped = <MediaItem>[];
    for (final item in items) {
      final id = item.id ?? item.path;
      if (!existingIds.contains(id)) {
        deduped.add(item);
        existingIds.add(id);
      }
    }
    if (deduped.isEmpty) return;

    if (state.queue.isEmpty) {
      playPlaylist(deduped);
    } else {
      _queue.appendTracks(deduped);
      state = state.copyWith(queue: [...state.queue, ...deduped]);
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

  void adjustLyricsOffset(Duration delta) {
    final current = state.currentTrack;
    if (current != null) {
      final updatedTrack = current.copyWith(
        lyricsOffset: current.lyricsOffset + delta,
      );
      state = state.copyWith(currentTrack: updatedTrack);
      final updatedQueue = state.queue.map((track) {
        if ((track.id ?? track.path) == (current.id ?? current.path)) {
          return updatedTrack;
        }
        return track;
      }).toList();
      state = state.copyWith(queue: updatedQueue);
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
      if (fromCompletion && state.loopMode == LoopMode.one) {
        ref
            .read(notificationProvider.notifier)
            .showNotification(
              'Track Repeating',
              'Repeating: ${nextTrack.title}',
            );
      }
      _playCurrentFromQueue(nextTrack).then((_) => _isNavigating = false);
    } else if (fromCompletion) {
      _isNavigating = false;
      pause();
      seek(Duration.zero);
      ref
          .read(notificationProvider.notifier)
          .showNotification(
            'Queue Completed',
            'Finished playing all tracks in the queue.',
          );
    } else {
      _isNavigating = false;
    }
    state = state.copyWith(currentIndex: _queue.currentIndex);
    _updateNextTrack();
  }

  void previous() {
    if (_isNavigating) return;
    _isNavigating = true;
    final prev = _queue.getPreviousTrack();
    if (prev != null) {
      _playCurrentFromQueue(prev).then((_) => _isNavigating = false);
    } else {
      _isNavigating = false;
    }
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
