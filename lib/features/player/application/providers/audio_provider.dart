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
import '../../../../core/data/services/media_cache_service.dart';

// ── Extracted Services ────────────────────────────────────────────────────────
import '../states/audio_state.dart';
import '../../data/services/audio_persistence_service.dart';
import '../../data/services/audio_metadata_service.dart';
import '../services/stream_resolution_service.dart';
import '../services/gapless_prefetch_service.dart';
import '../../../library/application/blocked_tracks_provider.dart';

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
    _updateNextTrack();
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
        if (position.inSeconds > 0) {
          _engine.resetErrorGuard();
        }

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
          ref.read(notificationProvider.notifier).showNotification(
            'Playback Stopped',
            'Continuous playback errors encountered. Stopped to prevent loop.',
            isError: true,
          );
          return;
        }

        // Transparent self-heal: re-resolve same track before skipping
        final errStr = error.toString().toLowerCase();
        final isStreamErr = errStr.contains('403') ||
            errStr.contains('forbidden') ||
            errStr.contains('expired') ||
            errStr.contains('failed to open');
        if (isStreamErr && currentId != null && (state.currentTrack?.isStreaming ?? false)) {
          debugPrint('[AudioPlayer] Stream failure detected — attempting self-heal re-resolve for $currentId');
          Future.microtask(() async {
            try {
              final url = await ref.read(playbackArchitectureServiceProvider)
                  .getStreamUrl(currentId, forceRefresh: true);
              if (url != null) {
                debugPrint('[AudioPlayer] Self-heal success — resuming $currentId');
                await _player.open(
                  _resolver.buildMedia(url, player: _player),
                  play: true,
                );
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
    final idx = state.queue.indexWhere(
      (t) => (t.id ?? t.path) == (track.id ?? track.path),
    );
    await playTrack(track, index: idx);
  }

  // Public entry-point for YouTube / streaming tracks
  Future<void> playYouTubeTrack(MediaItem item, {int index = -1}) async {
    await playTrack(item, index: index);
  }

  Future<void> playTrack(MediaItem item, {int index = -1}) async {
    // Guard: normalize streaming item so path is always the video ID, never an ephemeral stream URL
    final cleanItem = (item.isStreaming &&
            item.path.startsWith('http') &&
            item.id != null &&
            item.id!.isNotEmpty)
        ? item.copyWith(path: item.id!)
        : item;

    final targetId = cleanItem.id ?? cleanItem.path;
    if (state.queue.isEmpty ||
        (index == -1 &&
            !state.queue.any((t) => (t.id ?? t.path) == targetId))) {
      _queue.setQueue([cleanItem], initialIndex: 0);
      state = state.copyWith(
        queue: [cleanItem],
        currentIndex: 0,
        isPlaylistMode: false,
        clearActivePlaylistId: true,
      );
      index = 0;
    } else if (index == -1) {
      index = state.queue.indexWhere((t) => (t.id ?? t.path) == targetId);
    }

    MediaItem trackToPlay = cleanItem;
    final isPhysicalLocal = (!cleanItem.isStreaming &&
            (cleanItem.path.contains('/') || cleanItem.path.contains('\\'))) ||
        cleanItem.path.endsWith('.m4a') ||
        cleanItem.path.endsWith('.mp3');

    if (cleanItem.isStreaming || !isPhysicalLocal) {
      state = state.copyWith(isLoading: true, currentTrack: cleanItem);
      try {
        final resolvedPath = await _resolver.resolve(cleanItem);
        trackToPlay = cleanItem.copyWith(path: resolvedPath);
      } on OfflinePlaybackException {
        debugPrint('[AudioNotifier] Offline — checking upcoming queue for playable tracks');
        state = state.copyWith(isPlaying: false, isLoading: false);

        final cacheService = ref.read(mediaCacheServiceProvider);
        int nextPlayableIndex = -1;

        for (int i = index + 1; i < state.queue.length; i++) {
          final t = state.queue[i];
          final isLocal = !t.isStreaming ||
              (t.path.isNotEmpty &&
                  !t.path.startsWith('http') &&
                  (t.path.contains('/') || t.path.contains('\\')));
          if (isLocal) {
            nextPlayableIndex = i;
            break;
          }
          final cachedPath = await cacheService.getCachedAudioPath(t.id ?? t.path);
          if (cachedPath != null) {
            nextPlayableIndex = i;
            break;
          }
        }

        if (nextPlayableIndex != -1) {
          ref.read(notificationProvider.notifier).showNotification(
            'You\'re Offline',
            'Skipping to next available offline track.',
            target: 'target:download',
            silentOsNotification: true,
          );
          await playTrack(state.queue[nextPlayableIndex], index: nextPlayableIndex);
        } else {
          ref.read(notificationProvider.notifier).showNotification(
            'You\'re Offline',
            'No offline playable tracks remaining in queue.',
            target: 'target:download',
            silentOsNotification: true,
          );
        }
        return;
      } catch (e) {
        debugPrint('[AudioNotifier] Stream resolution failed in playTrack: $e');
        state = state.copyWith(isPlaying: false, isLoading: false);
        return;
      }
    }

    _onTrackChanged(cleanItem, index);
    state = state.copyWith(isLoading: true);
    try {
      await _player.open(_resolver.buildMedia(trackToPlay.path, player: _player), play: true);
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
    String? playlistId,
  }) async {
    if (items.isEmpty) return;
    final blocked = ref.read(blockedTracksProvider.notifier);
    final validItems = items.where((t) => !blocked.isBlocked(t.id, path: t.path)).toList();
    if (validItems.isEmpty) return;

    final safeIndex = initialIndex.clamp(0, validItems.length - 1);
    _queue.setQueue(validItems, initialIndex: safeIndex);
    state = state.copyWith(
      queue: validItems,
      currentIndex: safeIndex,
      isPlaylistMode: true,
      activePlaylistId: playlistId,
      clearActivePlaylistId: playlistId == null,
    );
    await _playCurrentFromQueue(validItems[safeIndex]);
    final ids = validItems
        .skip(safeIndex + 1)
        .where((e) => e.isStreaming)
        .take(3)
        .map((e) => e.id ?? e.path)
        .toList();
    if (ids.isNotEmpty) {
      ref.read(playbackArchitectureServiceProvider).predictiveFetch(ids);
    }
  }

  void addTrackToQueue(MediaItem item) {
    addToQueue(item);
  }

  /// Plays [item] next after the currently playing song.
  void playNext(MediaItem item) {
    if (ref.read(blockedTracksProvider.notifier).isBlocked(item.id, path: item.path)) {
      ref.read(notificationProvider.notifier).showNotification(
        'Track Blocked',
        '"${item.title}" is in your blocked list.',
        target: 'target:blocked_tracks',
        silentOsNotification: true,
      );
      return;
    }

    if (state.queue.isEmpty || state.currentTrack == null) {
      if (item.isStreaming) {
        playYouTubeTrack(item);
      } else {
        playTrack(item);
      }
      return;
    }

    _queue.insertTrackNext(item);
    state = state.copyWith(queue: List.from(_queue.queue));
    _updateNextTrack();

    ref.read(notificationProvider.notifier).showNotification(
      'Playing Next',
      'Added "${item.title}" to play next.',
      target: 'target:queue',
      silentOsNotification: true,
    );
  }

  /// Appends [item] to queue with notification.
  void addToQueue(MediaItem item) {
    if (ref.read(blockedTracksProvider.notifier).isBlocked(item.id, path: item.path)) {
      ref.read(notificationProvider.notifier).showNotification(
        'Track Blocked',
        '"${item.title}" is in your blocked list.',
        target: 'target:blocked_tracks',
        silentOsNotification: true,
      );
      return;
    }

    final itemId = item.id ?? item.path;
    final exists = state.queue.any((t) => (t.id ?? t.path) == itemId);
    if (exists) {
      ref.read(notificationProvider.notifier).showNotification(
        'Already in Queue',
        '"${item.title}" is already in the queue.',
        target: 'target:queue',
        silentOsNotification: true,
      );
      return;
    }

    if (state.queue.isEmpty) {
      if (item.isStreaming) {
        playYouTubeTrack(item);
      } else {
        playTrack(item);
      }
    } else {
      _queue.appendTrack(item);
      state = state.copyWith(queue: List.from(_queue.queue));
      _updateNextTrack();
      ref.read(notificationProvider.notifier).showNotification(
        'Added to Queue',
        'Added "${item.title}" to queue.',
        target: 'target:queue',
        silentOsNotification: true,
      );
    }
  }

  /// Batch-appends tracks to queue. Fires _updateNextTrack once — not once per track.
  void addTracksToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    final blocked = ref.read(blockedTracksProvider.notifier);
    // Deduplicate incoming tracks against current queue and within the batch
    final existingIds = state.queue.map((t) => t.id ?? t.path).toSet();
    final deduped = <MediaItem>[];
    for (final item in items) {
      final id = item.id ?? item.path;
      if (!existingIds.contains(id) && !blocked.isBlocked(item.id, path: item.path)) {
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

  void reorderQueue(int oldIndex, int newIndex) {
    _queue.reorderQueue(oldIndex, newIndex);
    state = state.copyWith(
      queue: List.from(_queue.queue),
      currentIndex: _queue.currentIndex,
    );
    _updateNextTrack();
    ref.read(gaplessPrefetchServiceProvider).resetLock();
    ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
  }

  void removeTrackFromQueue(int index) {
    _queue.removeTrackAt(index);
    state = state.copyWith(
      queue: List.from(_queue.queue),
      currentIndex: _queue.currentIndex,
    );
    _updateNextTrack();
    ref.read(gaplessPrefetchServiceProvider).resetLock();
    ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
  }

  void removeTrackFromQueueById(String id) {
    _queue.removeTrackById(id);
    state = state.copyWith(
      queue: List.from(_queue.queue),
      currentIndex: _queue.currentIndex,
    );
    _updateNextTrack();
    ref.read(gaplessPrefetchServiceProvider).resetLock();
    ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
  }

  void clearUpcomingQueue() {
    _queue.clearUpcoming();
    state = state.copyWith(
      queue: List.from(_queue.queue),
      currentIndex: _queue.currentIndex,
    );
    _updateNextTrack();
    ref.read(gaplessPrefetchServiceProvider).resetLock();
  }

  Future<void> jumpToQueueIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    _queue.updateIndex(index);
    state = state.copyWith(currentIndex: index);
    await _playCurrentFromQueue(state.queue[index]);
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
      clearCurrentTrack: true,
      isPlaying: false,
      queue: [],
      currentIndex: -1,
      nextTrack: null,
      clearNextTrack: true,
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
            target: 'target:queue',
            silentOsNotification: true,
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
    final next = _queue.peekNextTrack(state.loopMode, state.isShuffleEnabled);
    state = state.copyWith(
      nextTrack: next,
      clearNextTrack: next == null,
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
