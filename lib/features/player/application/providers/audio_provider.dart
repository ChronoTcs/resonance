import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/providers/cached_stream_music_provider.dart';
import '../services/queue_orchestrator.dart';

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
import '../../../../core/application/providers/window_lifecycle_provider.dart';
import '../../../../core/providers/overlay_provider.dart';
import 'sleep_timer_provider.dart';

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

  // ── Navigation & Self-Heal guards ──────────────────────────────────────────
  bool _isNavigating = false;
  final List<StreamSubscription> _subscriptions = [];
  DateTime? _lastCompletionTime;
  late ResonanceAudioHandler _audioHandler;
  AudioSession? _audioSession;
  bool _wasPlayingBeforeInterruption = false;
  double? _preDuckVolume;

  int _prematureEofRetries = 0;
  String? _lastRetriedTrackId;
  bool _isSelfHealing = false;

  /// Records the real hardware position of the outgoing track right before a track change.
  /// Prevents minimized Windows UI state (where state.position is frozen) from tricking
  /// AudioOrchestrator into thinking a finished track was fast-skipped (< 15s).
  Duration lastTrackFinalPosition = Duration.zero;
  Duration lastTrackFinalDuration = Duration.zero;

  static const MethodChannel _androidPlatformChannel =
      MethodChannel('com.chronostudio.resonance/potoken');

  void _setAndroidPlaybackLocks(bool active) {
    if (!isAndroid) return;
    Future.microtask(() async {
      try {
        await _androidPlatformChannel.invokeMethod('setPlaybackLocks', {'active': active});
      } catch (_) {}
    });
  }

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
    _audioHandler = audioHandler;
    _player = audioHandler.player;

    audioHandler.onPlay = () => play();
    audioHandler.onPause = () => pause();
    audioHandler.onStop = () => stop();
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
      _setAndroidPlaybackLocks(false);
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
      _audioSession = session;
      await session.configure(const AudioSessionConfiguration.music());

      _subscriptions.add(session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _preDuckVolume = state.volume;
              _player.setVolume(state.volume * 0.2);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              final currentlyPlaying = state.isPlaying || _player.state.playing;
              if (currentlyPlaying) {
                _wasPlayingBeforeInterruption = true;
                _player.pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (_preDuckVolume != null) {
                _player.setVolume(_preDuckVolume!);
                _preDuckVolume = null;
              } else {
                _player.setVolume(state.volume);
              }
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_wasPlayingBeforeInterruption) {
                _wasPlayingBeforeInterruption = false;
                play();
              }
              break;
          }
        }
      }));

      _subscriptions.add(session.becomingNoisyEventStream.listen((_) {
        debugPrint('[AudioNotifier] Audio becoming noisy — auto-pausing playback');
        if (state.isPlaying || _player.state.playing) {
          pause();
        }
      }));
    } catch (e) {
      debugPrint('[AudioNotifier] Audio session config failed: $e');
    }
  }

  /// Re-resolves a dropped/throttled streaming track, purges any corrupted local cache file,
  /// opens the fresh stream, and seeks back to [resumePosition] once the demuxer reports duration.
  Future<void> _selfHealMidStream(String trackId, Duration resumePosition) async {
    if (_isSelfHealing) return;
    _isSelfHealing = true;
    try {
      if (!ref.read(networkConnectivityProvider).isOnline) {
        debugPrint('[AudioPlayer] Offline — cannot self-heal stream, switching to offline playback');
        if (state.currentTrack != null) {
          await _handleOfflinePlayback(state.currentTrack!, state.currentIndex);
        }
        return;
      }

      final archService = ref.read(playbackArchitectureServiceProvider);
      await archService.invalidateAndPurgeDisk(trackId);
      final url = await archService.getStreamUrl(trackId, forceRefresh: true);

      if (url != null) {
        debugPrint(
          '[AudioPlayer] Self-heal resolved fresh stream for $trackId — resuming at ${resumePosition.inSeconds}s',
        );
        if (isAndroid && _audioSession != null) {
          await _audioSession!.setActive(true);
        }
        await _player.open(
          _resolver.buildMedia(url, player: _player),
          play: true,
        );

        if (resumePosition.inMilliseconds > 1000) {
          StreamSubscription<Duration>? seekSub;
          Timer? seekTimeout;
          seekSub = _player.stream.duration.listen((dur) {
            final currentId = state.currentTrack?.id ?? state.currentTrack?.path;
            if (currentId != trackId) {
              seekTimeout?.cancel();
              seekSub?.cancel();
              return;
            }
            if (dur > Duration.zero) {
              seekTimeout?.cancel();
              seekSub?.cancel();
              _audioHandler.seek(resumePosition);
            }
          });
          seekTimeout = Timer(const Duration(seconds: 6), () {
            seekSub?.cancel();
          });
        }
        return;
      }
    } on OfflinePlaybackException {
      if (state.currentTrack != null) {
        await _handleOfflinePlayback(state.currentTrack!, state.currentIndex);
      }
      return;
    } catch (e) {
      debugPrint('[AudioPlayer] Self-heal exception for $trackId: $e');
    } finally {
      _isSelfHealing = false;
    }

    debugPrint('[AudioPlayer] Self-heal failed for $trackId — advancing queue');
    if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
      next(fromCompletion: true);
    }
  }

  // ── Player Stream Listeners ────────────────────────────────────────────────

  void _initListeners() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        if (state.isLoading && !playing) {
          // Ignore transient playing=false emitted by libmpv while _player.open(..., play: true) is loading
          return;
        }
        state = state.copyWith(isPlaying: playing);
        if (playing) _isNavigating = false;
        _setAndroidPlaybackLocks(playing);
        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          _metadata.onPlaybackStatusChanged(
            currentTrack: state.currentTrack,
            isPlaying: playing,
            // While loading a new track, _player.state.position still holds the outgoing track's position
            position: state.isLoading ? state.position : _player.state.position,
            duration: state.duration,
          );
        }
      }),

      _player.stream.position.listen((position) {
        if (state.isLoading) {
          // Ignore residual position ticks from the outgoing track while _player.open() is transitioning
          return;
        }
        if (position.inSeconds > 0) {
          _engine.resetErrorGuard();
          lastTrackFinalPosition = position;
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

        // Skip UI state rebuilds when window is minimized or hidden to tray
        if (!ref.read(isWindowRenderActiveProvider)) {
          return;
        }

        // Throttle high-frequency mpv position updates (20-50 Hz -> 5 Hz normal, ~12 Hz when lyrics open)
        final isLyricsOpen = ref.read(lyricsOverlayProvider);
        final minDeltaMs = isLyricsOpen ? 80 : 200;
        final deltaMs = (position.inMilliseconds - state.position.inMilliseconds).abs();
        if (position == Duration.zero || deltaMs >= minDeltaMs) {
          state = state.copyWith(position: position);
        }
      }),

      _player.stream.duration.listen((d) {
        if (d > Duration.zero) {
          lastTrackFinalDuration = d;
        }
        if (d > Duration.zero &&
            state.currentTrack != null &&
            (state.currentTrack!.duration == null ||
                state.currentTrack!.duration == Duration.zero)) {
          final updatedTrack = state.currentTrack!.copyWith(duration: d);
          state = state.copyWith(duration: d, currentTrack: updatedTrack);
          _metadata.onPlaybackStatusChanged(
            currentTrack: updatedTrack,
            isPlaying: state.isPlaying,
            position: state.isLoading ? state.position : _player.state.position,
            duration: d,
          );
        } else if (d > Duration.zero) {
          state = state.copyWith(duration: d);
        }
      }),
      _player.stream.volume.listen((v) => state = state.copyWith(volume: v)),

      _player.stream.completed.listen((completed) {
        if (!completed || _isSelfHealing) return;
        final now = DateTime.now();
        if (_lastCompletionTime != null &&
            now.difference(_lastCompletionTime!).inMilliseconds < 800) {
          return;
        }
        _lastCompletionTime = now;

        final completedTrack = state.currentTrack;
        // CRITICAL: Always read _player.state.position (or lastTrackFinalPosition), NEVER state.position!
        // When Windows is minimized (!isWindowRenderActiveProvider), state.position is frozen.
        final playerPos = _player.state.position;
        final actualPos = playerPos > lastTrackFinalPosition ? playerPos : lastTrackFinalPosition;
        final playerDur = _player.state.duration;
        final actualDur = playerDur > Duration.zero
            ? playerDur
            : (lastTrackFinalDuration > Duration.zero
                ? lastTrackFinalDuration
                : (state.duration > Duration.zero
                    ? state.duration
                    : (completedTrack?.duration ?? Duration.zero)));

        // [Premature EOF Guard]
        // If a streaming track emits completed (eof-reached) before reaching 85% of its duration,
        // it suffered a mid-stream CDN drop or played a truncated .m4a cache file.
        final isPrematureEof = completedTrack != null &&
            completedTrack.isStreaming &&
            actualDur.inSeconds > 30 &&
            actualPos.inMilliseconds > 3000 &&
            actualPos.inMilliseconds < (actualDur.inMilliseconds * 0.85);

        if (isPrematureEof) {
          final trackId = completedTrack.id ?? completedTrack.path;
          if (_lastRetriedTrackId != trackId) {
            _lastRetriedTrackId = trackId;
            _prematureEofRetries = 0;
          }
          if (_prematureEofRetries < 2) {
            _prematureEofRetries++;
            debugPrint(
              '[AudioNotifier] Premature EOF detected for $trackId at '
              '${actualPos.inSeconds}s / ${actualDur.inSeconds}s '
              '(retry $_prematureEofRetries/2). Self-healing...',
            );
            Future.microtask(() => _selfHealMidStream(trackId, actualPos));
            return; // Do NOT run completion caching and do NOT skip to next track!
          } else {
            debugPrint(
              '[AudioNotifier] Premature EOF retries exhausted for $trackId — advancing queue.',
            );
          }
        }

        // [State-Based Completion Caching]
        // Only trigger background cache for tracks that played as live network streams AND completed legitimately.
        // Skip completion caching if LoopMode.one is active to avoid concurrent live CDN socket collision (0xffffd8ba).
        final wasLiveStream = completedTrack != null &&
            completedTrack.isStreaming &&
            (completedTrack.path.startsWith('http') ||
                (!completedTrack.path.contains('/stream/audio/') &&
                    !completedTrack.path.contains(r'\stream\audio\')));

        if (completedTrack != null && wasLiveStream && state.loopMode != LoopMode.one) {
          final completedId = completedTrack.id ?? completedTrack.path;
          final archService = ref.read(playbackArchitectureServiceProvider);
          Future.microtask(() async {
            try {
              final cacheService = ref.read(mediaCacheServiceProvider);
              final existingCache = await cacheService.getCachedAudioPath(completedId);
              if (existingCache == null && !cacheService.isCaching(completedId)) {
                final streamUrl = await archService.getStreamUrl(completedId);
                if (streamUrl != null && streamUrl.startsWith('http')) {
                  final headers = _resolver.getHeaders(streamUrl);
                  debugPrint('[AudioNotifier] Caching completed live stream for $completedId');
                  cacheService.getAudioPath(completedId, streamUrl, headers: headers);
                }
              }
            } catch (_) {}
          });
        }

        if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          // [Sleep Timer - End of Track Guard]
          final sleepTimer = ref.read(sleepTimerProvider);
          if (sleepTimer.isEndOfTrack) {
            ref.read(sleepTimerProvider.notifier).triggerEndOfTrackStop();
            pause();
            seek(Duration.zero);
            return;
          }

          next(fromCompletion: true);
        }
      }),

      // ── Anti-Loop Error Guard ─────────────────────────────────────────────
      _player.stream.error.listen((error) {
        debugPrint('[AudioPlayer] [ERROR] Streaming / Playback error: $error');
        final currentId = state.currentTrack?.id ?? state.currentTrack?.path;
        final playerPos = _player.state.position;
        final resumePos = playerPos > lastTrackFinalPosition ? playerPos : lastTrackFinalPosition;

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

        // Transparent self-heal: re-resolve same track and resume at interrupted position before skipping
        final errStr = error.toString().toLowerCase();
        final isStreamErr = errStr.contains('403') ||
            errStr.contains('forbidden') ||
            errStr.contains('expired') ||
            errStr.contains('failed to open') ||
            errStr.contains('tcp:') ||
            errStr.contains('ffurl_') ||
            errStr.contains('0xffffd8ba') ||
            errStr.contains('connection reset') ||
            errStr.contains('econnreset') ||
            errStr.contains('broken pipe') ||
            errStr.contains('error decoding audio') ||
            errStr.contains('end of file') ||
            errStr.contains('eof');
        if (isStreamErr && currentId != null && (state.currentTrack?.isStreaming ?? false)) {
          debugPrint('[AudioPlayer] Stream failure detected — attempting self-heal re-resolve for $currentId');
          Future.microtask(() => _selfHealMidStream(currentId, resumePos));
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

  void _onTrackChanged(MediaItem track, int index, {bool? isPlaying}) {
    final prevId = state.currentTrack?.id ?? state.currentTrack?.path;
    final nextId = track.id ?? track.path;
    if (prevId != nextId) {
      // Snapshot outgoing track's real hardware position before resetting for the new track
      final hwPos = _player.state.position;
      if (hwPos > lastTrackFinalPosition) {
        lastTrackFinalPosition = hwPos;
      }
      _prematureEofRetries = 0;
      _lastRetriedTrackId = nextId;
    }

    final cleanTrack = track.copyWith(lyricsOffset: Duration.zero);
    final playing = isPlaying ?? state.isPlaying;
    state = state.copyWith(
      currentTrack: cleanTrack,
      currentIndex: index,
      isPlaying: playing,
      position: Duration.zero,
      duration: cleanTrack.duration ?? Duration.zero,
    );
    if (prevId != nextId) {
      // Reset live trackers for the incoming track after state transition listeners have fired
      Future.microtask(() {
        lastTrackFinalPosition = Duration.zero;
        lastTrackFinalDuration = cleanTrack.duration ?? Duration.zero;
      });
    }
    if (index != -1) _queue.setCurrentIndex(index);
    _metadata.onTrackChanged(track, isPlaying: playing);
    final songId = track.id ?? track.path;
    if (track.isStreaming) {
      ref.read(streamCacheTrackerServiceProvider).updateLastPlayed(songId);
    }
    _updateNextTrack();
    ref.read(recentlyPlayedProvider.notifier).addTrack(track);

    _persistence.savePlaybackState(
      trackJson: jsonEncode(track.toJson(includeArt: false)),
      queueJson: state.queue.map((t) => jsonEncode(t.toJson(includeArt: false))).toList(),
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

  Future<void> _replayCurrentTrackForRepeatOne({bool fromCompletion = false}) async {
    final track = state.currentTrack;
    if (track == null) return;
    try {
      // If player already has media loaded, seek(zero) provides seamless loop
      // without destroying native AudioTrack (Android) or clearing libmpv demuxer cache (Windows).
      if (_player.state.playlist.medias.isNotEmpty) {
        await _audioHandler.seek(Duration.zero);
        play();
        state = state.copyWith(position: Duration.zero, isPlaying: true);
        return;
      }

      // Fallback only if player media was unloaded/empty
      final playablePath = await _resolver.resolve(track);
      if (isAndroid && _audioSession != null) {
        await _audioSession!.setActive(true);
      }
      await _player.open(_resolver.buildMedia(playablePath, player: _player), play: true);
      state = state.copyWith(position: Duration.zero, isPlaying: true);
    } catch (e) {
      debugPrint('[AudioNotifier] Repeat-one stream replay failed: $e');
      await _audioHandler.seek(Duration.zero);
      play();
    }
  }

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
    if (ref.read(blockedTracksProvider.notifier).isBlocked(item.id, path: item.path)) {
      ref.read(notificationProvider.notifier).showNotification(
        'Track Blocked',
        '"${item.title}" is in your blocked list.',
        target: 'target:blocked_tracks',
        silentOsNotification: true,
      );
      return;
    }

    // Guard: normalize streaming item so id and path are always the canonical video ID, never an ephemeral stream URL
    final normalizedId = (item.id != null && item.id!.isNotEmpty)
        ? item.id!
        : (item.isStreaming && !item.path.startsWith('http') ? item.path : item.id);
    final cleanItem = (item.isStreaming &&
            item.path.startsWith('http') &&
            normalizedId != null &&
            normalizedId.isNotEmpty)
        ? item.copyWith(id: normalizedId, path: normalizedId)
        : (normalizedId != null && item.id == null
            ? item.copyWith(id: normalizedId)
            : item);

    final targetId = cleanItem.id ?? cleanItem.path;
    if (state.queue.isEmpty || (index == -1 && !state.isPlaylistMode)) {
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
      if (index == -1) {
        _queue.setQueue([cleanItem], initialIndex: 0);
        state = state.copyWith(
          queue: [cleanItem],
          currentIndex: 0,
          isPlaylistMode: false,
          clearActivePlaylistId: true,
        );
        index = 0;
      }
    }

    String playablePath = cleanItem.path;
    final isPhysicalLocal = (!cleanItem.isStreaming &&
            (cleanItem.path.contains('/') || cleanItem.path.contains('\\'))) ||
        cleanItem.path.endsWith('.m4a') ||
        cleanItem.path.endsWith('.mp3');

    if (cleanItem.isStreaming || !isPhysicalLocal) {
      // [Fast-Skip Collision Abort] Abort any in-flight background pre-cache for this song
      // so the live player connection has 100% exclusive access without socket collisions (0xffffd8ba).
      ref.read(mediaCacheServiceProvider).cancelActiveDownload(targetId);

      state = state.copyWith(isLoading: true, currentTrack: cleanItem);
      try {
        playablePath = await _resolver.resolve(cleanItem);
      } on OfflinePlaybackException {
        await _handleOfflinePlayback(cleanItem, index);
        return;
      } catch (e) {
        debugPrint('[AudioNotifier] Stream resolution failed in playTrack: $e');
        state = state.copyWith(isPlaying: false, isLoading: false);

        final isOffline = !ref.read(networkConnectivityProvider).isOnline;
        if (isOffline) {
          await _handleOfflinePlayback(cleanItem, index);
          return;
        }

        // [Resilient Queue] Never leave player frozen. Auto-skip on completion-triggered failure.
        Future.microtask(() async {
          try {
            // 1 retry with forceRefresh before giving up
            debugPrint('[AudioNotifier] Retrying resolution for ${cleanItem.id ?? cleanItem.path}');
            final retryPath = await _resolver.resolveForced(cleanItem);
            _onTrackChanged(cleanItem, index, isPlaying: true);
            state = state.copyWith(isLoading: true, isPlaying: true);
            if (isAndroid && _audioSession != null) {
              await _audioSession!.setActive(true);
            }
            await _player.open(_resolver.buildMedia(retryPath, player: _player), play: true);
            state = state.copyWith(isLoading: false);
            return;
          } catch (retryError) {
            if (retryError is OfflinePlaybackException || !ref.read(networkConnectivityProvider).isOnline) {
              await _handleOfflinePlayback(cleanItem, index);
              return;
            }
          }
          // Retry also failed — auto-skip if from queue completion
          debugPrint('[AudioNotifier] Retry failed — auto-advancing queue');
          ref.read(notificationProvider.notifier).showNotification(
            'Skipping Unplayable Track',
            '"${cleanItem.title}" could not be loaded.',
            isError: true,
            silentOsNotification: true,
          );
          if (ref.read(mediaFocusProvider) == MediaFocus.audio) {
          final sleepTimer = ref.read(sleepTimerProvider);
          if (sleepTimer.isEndOfTrack) {
            ref.read(sleepTimerProvider.notifier).triggerEndOfTrackStop();
            pause();
            seek(Duration.zero);
            return;
          }

          next(fromCompletion: true);
          }
        });
        return;
      }
    }

    _onTrackChanged(cleanItem, index, isPlaying: true);
    state = state.copyWith(isLoading: true, currentTrack: cleanItem, isPlaying: true);
    try {
      if (isAndroid && _audioSession != null) {
        await _audioSession!.setActive(true);
      }
      await _player.open(_resolver.buildMedia(playablePath, player: _player), play: true);
    } catch (e) {
      debugPrint('[AudioNotifier] CRITICAL: Error opening track: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
    _updateNextTrack();
  }

  Future<void> _handleOfflinePlayback(MediaItem cleanItem, int index) async {
    debugPrint('[AudioNotifier] Offline — scanning upcoming queue for playable tracks');
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
      return;
    }

    // Queue has no more offline tracks! Fallback to Cached Stream Music library
    List<MediaItem> cachedTracks = const [];
    try {
      cachedTracks = await ref.read(cachedStreamMusicProvider.future);
    } catch (_) {
      cachedTracks = ref.read(cachedStreamMusicProvider).asData?.value ?? const <MediaItem>[];
    }
    final blockedNotifier = ref.read(blockedTracksProvider.notifier);
    final playableCached = cachedTracks
        .where((t) => !blockedNotifier.isBlocked(t.id, path: t.path))
        .toList();

    if (playableCached.isNotEmpty) {
      ref.read(notificationProvider.notifier).showNotification(
        'You\'re Offline',
        'Queue exhausted. Switching to your cached stream music library.',
        target: 'target:download',
        silentOsNotification: true,
      );
      debugPrint(
        '[AudioNotifier] Queue exhausted offline — falling back to ${playableCached.length} cached stream tracks',
      );
      ref.read(queueOrchestratorProvider).playOfflineRadioFallback(
        failedTrack: cleanItem,
        cachedTracks: playableCached,
      );
      return;
    }

    // Zero cached or local tracks available on entire machine
    ref.read(notificationProvider.notifier).showNotification(
      'You\'re Offline',
      'No offline playable tracks remaining in queue.',
      target: 'target:download',
      silentOsNotification: true,
    );
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
    // Deprecated: Speculative prefetch removed. GaplessPrefetchService handles active queue pre-caching.
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
      final updatedQueue = state.queue.map((track) {
        if ((track.id ?? track.path) == (current.id ?? current.path)) {
          return updatedTrack;
        }
        return track;
      }).toList();
      state = state.copyWith(
        currentTrack: updatedTrack,
        queue: updatedQueue,
      );
    }
  }

  void play() {
    _wasPlayingBeforeInterruption = false;
    if (isAndroid && _audioSession != null) {
      _audioSession!.setActive(true);
    }
    _setAndroidPlaybackLocks(true);
    // Self-healing recovery: if player stopped or libmpv playlist is empty, re-open currentTrack
    if (_player.state.playlist.medias.isEmpty && state.currentTrack != null) {
      debugPrint('[AudioNotifier] Play called but libmpv media empty — recovering via _playCurrentFromQueue');
      _playCurrentFromQueue(state.currentTrack!);
      return;
    }
    _player.play();
  }

  void pause() {
    _wasPlayingBeforeInterruption = false;
    _setAndroidPlaybackLocks(false);
    _player.pause();
  }

  void stop() {
    _wasPlayingBeforeInterruption = false;
    _setAndroidPlaybackLocks(false);
    _player.stop();
    if (isAndroid && _audioSession != null) {
      _audioSession!.setActive(false);
    }
  }

  void stopAndClear() {
    // 1. Stop native engine first so libmpv releases open .m4a file descriptors immediately
    stop();
    // 2. Abort any scheduled gapless prefetch / waterfall worker timers and in-flight metadata upgrades
    try {
      ref.read(gaplessPrefetchServiceProvider).resetLock();
    } catch (_) {}
    _metadata.cancelPendingUpgrades();

    // 3. Reset internal navigation/recovery trackers and queue state
    _isNavigating = false;
    _isSelfHealing = false;
    _prematureEofRetries = 0;
    _lastRetriedTrackId = null;
    lastTrackFinalPosition = Duration.zero;
    lastTrackFinalDuration = Duration.zero;

    _queue.setQueue([], initialIndex: -1);
    state = state.copyWith(
      currentTrack: null,
      clearCurrentTrack: true,
      isPlaying: false,
      isLoading: false,
      queue: [],
      currentIndex: -1,
      nextTrack: null,
      clearNextTrack: true,
      position: Duration.zero,
      duration: Duration.zero,
    );
    try {
      _audioHandler.notifyQueueCompleted();
    } catch (_) {}
    unawaited(_persistence.clearPlaybackState());
  }

  void togglePlayPause() => state.isPlaying ? pause() : play();

  void next({bool fromCompletion = false}) {
    if (_isNavigating) return;
    if (fromCompletion && ref.read(mediaFocusProvider) != MediaFocus.audio) {
      return stop();
    }
    if (state.queue.isEmpty) return stop();

    if (state.loopMode == LoopMode.one && state.currentTrack != null) {
      _isNavigating = true;
      _replayCurrentTrackForRepeatOne(fromCompletion: fromCompletion).whenComplete(() {
        _isNavigating = false;
      });
      return;
    }

    _isNavigating = true;
    final nextTrack = _queue.getNextTrack(
      state.loopMode,
      state.isShuffleEnabled,
      fromCompletion: fromCompletion,
    );

    if (nextTrack != null) {
      _playCurrentFromQueue(nextTrack).whenComplete(() => _isNavigating = false);
    } else if (fromCompletion) {
      _isNavigating = false;
      pause();
      if (isAndroid && _audioSession != null) {
        _audioSession!.setActive(false);
      }
      seek(Duration.zero);
      try {
        _audioHandler.notifyQueueCompleted();
      } catch (_) {}
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
      _playCurrentFromQueue(prev).whenComplete(() => _isNavigating = false);
    } else {
      _isNavigating = false;
    }
    state = state.copyWith(currentIndex: _queue.currentIndex);
    _updateNextTrack();
  }

  void skipToNext() => next();
  void skipToPrevious() {
    final currentPos = _player.state.position > state.position
        ? _player.state.position
        : state.position;
    if (currentPos.inSeconds > 3) {
      seek(Duration.zero);
    } else {
      previous();
    }
  }

  void seek(Duration position) => _audioHandler.seek(position);
  void adjustVolume(double delta) =>
      setVolume((state.volume + delta).clamp(0.0, 100.0));
  void adjustPosition(Duration delta) {
    final currentPos = _player.state.position > state.position
        ? _player.state.position
        : state.position;
    final currentDur = _player.state.duration > Duration.zero
        ? _player.state.duration
        : state.duration;
    final raw = currentPos + delta;
    final clamped = raw < Duration.zero
        ? Duration.zero
        : (raw > currentDur ? currentDur : raw);
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
