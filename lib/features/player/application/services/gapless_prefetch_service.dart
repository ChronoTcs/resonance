import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/data/services/media_cache_service.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/sleep_timer_provider.dart';
import '../../data/models/player_enums.dart';
import '../services/queue_service.dart';
import '../services/stream_resolution_service.dart';
import 'playback_architecture_service.dart';

/// Proactively resolves and pre-caches the upcoming track (N+1) into local disk
/// so playback is gapless and consumes 0MB streaming data on transition.
///
/// Features 3-Tier Waterfall Caching (Active track N is cached post-completion in AudioNotifier):
/// - Slot 1 (Tier 1): Upcoming track N+1 full audio disk pre-cache (15s delay)
/// - Slot 2 (Tier 2): N+2 lightweight URL pre-warm (20s delay)
/// - Waterfall Worker (Tier 3): Paced serial queue worker for N+3..N+K (25s delay)
class GaplessPrefetchService {
  final Ref _ref;

  // Guardrails: prevent concurrent double-fetch per slot
  bool _isFetchingFirst = false;
  bool _isFetchingSecond = false;
  bool _isWaterfallRunning = false;

  // Timers
  Timer? _stabilizationTimer;
  Timer? _staggerTimer;
  Timer? _waterfallTimer;

  // Generation token for Waterfall Worker cancellation on skip/queue mutation
  int _currentGeneration = 0;

  // Cooldown backoff on 429/403 rate-limits
  DateTime? _waterfallCooldownUntil;

  GaplessPrefetchService(this._ref);

  /// Schedules Slot 1 (N+1), Slot 2 (N+2), and Tier 3 Waterfall Worker.
  /// Note: Active track (N) is cached post-completion in AudioNotifier after FFmpeg closes its socket,
  /// preventing concurrent HTTP socket collisions on single-connection YouTube CDN URLs.
  /// Safe to call on every track change — resetLock() clears prior timers and increments generation.
  Future<void> proactiveFetch() async {
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      resetLock();
      return;
    }

    // ── LoopMode.one & End-of-Track Sleep Timer Guard ─────────────────────
    // In Repeat One or when Sleep Timer End-of-Track is armed, the active track will not advance
    // to N+1. Pre-caching N+1, pre-warming N+2, and running the Waterfall Worker across the queue
    // is wasteful, exhausts mobile data, and burns rate limits for tracks that will not play next.
    final currentAudioState = _ref.read(audioProvider);
    final sleepTimer = _ref.read(sleepTimerProvider);
    if (currentAudioState.loopMode == LoopMode.one || sleepTimer.isEndOfTrack) {
      _stabilizationTimer?.cancel();
      _staggerTimer?.cancel();
      _waterfallTimer?.cancel();
      return;
    }

    // ── Slot 1: N+1 Full Audio Pre-Cache (15s stabilization delay) ─────────
    _stabilizationTimer?.cancel();
    _stabilizationTimer = Timer(const Duration(seconds: 15), () async {
      if (!_ref.read(networkConnectivityProvider).isOnline) return;
      final audioState = _ref.read(audioProvider);
      if (!audioState.isPlaying) return; // Yield if music paused

      final queueService = _ref.read(queueServiceProvider);
      final next1 = queueService.peekNextTrack(
        audioState.loopMode,
        audioState.isShuffleEnabled,
      );

      if (next1 != null && next1.isStreaming && !_isFetchingFirst) {
        final next1Id = next1.id ?? next1.path;
        final cacheService = _ref.read(mediaCacheServiceProvider);
        final cached = await cacheService.getCachedAudioPath(next1Id);

        if (cached == null && !cacheService.isCaching(next1Id)) {
          _isFetchingFirst = true;
          debugPrint('[Gapless] Pre-caching N+1 to disk: ${next1.title}');
          try {
            final archService = _ref.read(playbackArchitectureServiceProvider);
            final streamUrl = await archService.getStreamUrl(next1Id);
            if (streamUrl != null && streamUrl.startsWith('http')) {
              final resolver = _ref.read(streamResolutionServiceProvider);
              final headers = resolver.getHeaders(streamUrl);
              await cacheService.getAudioPath(next1Id, streamUrl, headers: headers);
              debugPrint('[Gapless] N+1 audio pre-cache initiated: ${next1.title}');
            }
          } catch (e) {
            debugPrint('[Gapless] N+1 pre-cache failed: $e');
          } finally {
            _isFetchingFirst = false;
          }
        }
      }
    });

    // ── Slot 2: N+2 URL Pre-warm (20s stagger) ─────────────────────────────
    _staggerTimer?.cancel();
    _staggerTimer = Timer(const Duration(seconds: 20), () async {
      if (!_ref.read(networkConnectivityProvider).isOnline) return;
      final currentState = _ref.read(audioProvider);
      if (!currentState.isPlaying) return;

      final qs = _ref.read(queueServiceProvider);
      final n2 = qs.peekAhead(2, shuffleEnabled: currentState.isShuffleEnabled);
      if (n2 == null || !n2.isStreaming || _isFetchingSecond) return;

      final n2Id = n2.id ?? n2.path;
      _isFetchingSecond = true;
      debugPrint('[Gapless] Pre-warming N+2 URL: ${n2.title}');
      try {
        final archService = _ref.read(playbackArchitectureServiceProvider);
        await archService.getStreamUrl(n2Id);
        debugPrint('[Gapless] N+2 URL pre-warmed: ${n2.title}');
      } catch (e) {
        debugPrint('[Gapless] N+2 URL pre-warm failed: $e');
      } finally {
        _isFetchingSecond = false;
      }
    });

    // ── Tier 3: Full Queue Waterfall Worker (25s delay) ───────────────────
    _waterfallTimer?.cancel();
    _waterfallTimer = Timer(const Duration(seconds: 25), () {
      _runWaterfallWorker(_currentGeneration);
    });
  }

  /// Serial background worker prefetching upcoming tracks (N+3..N+K) with anti-ban pacing.
  Future<void> _runWaterfallWorker(int generation) async {
    if (_isWaterfallRunning) return;
    if (!_ref.read(networkConnectivityProvider).isOnline) return;

    final deepPrefetchEnabled = _ref.read(appBehaviorProvider).deepQueuePrefetch;
    if (!deepPrefetchEnabled) return;

    if (_waterfallCooldownUntil != null && DateTime.now().isBefore(_waterfallCooldownUntil!)) {
      debugPrint('[Gapless] Tier 3 Waterfall paused until $_waterfallCooldownUntil due to rate-limit cooldown.');
      return;
    }

    _isWaterfallRunning = true;
    debugPrint('[Gapless] Tier 3 Waterfall Worker started for generation $generation.');

    try {
      final qs = _ref.read(queueServiceProvider);
      final audioState = _ref.read(audioProvider);
      if (!audioState.isPlaying) return;

      final upcomingTracks = qs.getUpcomingTracks(
        offset: 3,
        shuffleEnabled: audioState.isShuffleEnabled,
      );

      final cacheService = _ref.read(mediaCacheServiceProvider);
      final archService = _ref.read(playbackArchitectureServiceProvider);
      final resolver = _ref.read(streamResolutionServiceProvider);
      final random = Random();

      for (final track in upcomingTracks) {
        if (_currentGeneration != generation) {
          debugPrint('[Gapless] Tier 3 Waterfall aborted: generation mismatch ($generation != $_currentGeneration).');
          return;
        }

        final currentAudioState = _ref.read(audioProvider);
        if (!currentAudioState.isPlaying) {
          debugPrint('[Gapless] Tier 3 Waterfall paused: playback paused.');
          return;
        }

        if (!_ref.read(networkConnectivityProvider).isOnline) return;
        if (!track.isStreaming) continue;

        final trackId = track.id ?? track.path;
        final cached = await cacheService.getCachedAudioPath(trackId);
        if (cached != null || cacheService.isCaching(trackId)) {
          continue;
        }

        // Pacing delay with random jitter (4000ms - 6000ms) to avoid YouTube burst rate limits
        final jitterMs = 4000 + random.nextInt(2000);
        await Future.delayed(Duration(milliseconds: jitterMs));

        if (_currentGeneration != generation) return;

        debugPrint('[Gapless] Tier 3 Waterfall caching: ${track.title}');
        try {
          final streamUrl = await archService.getStreamUrl(trackId);
          if (_currentGeneration != generation || !_ref.read(audioProvider).isPlaying) {
            debugPrint('[Gapless] Tier 3 Waterfall aborted mid-resolve: generation/playback changed.');
            return;
          }
          if (streamUrl != null && streamUrl.startsWith('http')) {
            final headers = resolver.getHeaders(streamUrl);
            await cacheService.getAudioPath(trackId, streamUrl, headers: headers);
            debugPrint('[Gapless] Tier 3 Waterfall cached: ${track.title}');
          } else {
            debugPrint('[Gapless] Tier 3 Waterfall track failed to resolve: ${track.title}. Backing off 30s.');
            _waterfallCooldownUntil = DateTime.now().add(const Duration(seconds: 30));
            break;
          }
        } catch (e) {
          debugPrint('[Gapless] Tier 3 Waterfall track failed: $e. Setting 60s cooldown.');
          _waterfallCooldownUntil = DateTime.now().add(const Duration(seconds: 60));
          break;
        }
      }
    } catch (e) {
      debugPrint('[Gapless] Tier 3 Waterfall unexpected error: $e');
    } finally {
      _isWaterfallRunning = false;
    }
  }

  /// Reset all locks and cancel timers on track change or skip.
  /// Prevents ghost downloads for old tracks when user rapidly advances queue.
  void resetLock() {
    _currentGeneration++;
    _stabilizationTimer?.cancel();
    _stabilizationTimer = null;
    _staggerTimer?.cancel();
    _staggerTimer = null;
    _waterfallTimer?.cancel();
    _waterfallTimer = null;
    _isFetchingFirst = false;
    _isFetchingSecond = false;
    _isWaterfallRunning = false;
    debugPrint('[Gapless] Resetting prefetch locks and timers (generation=$_currentGeneration).');
  }
}

final gaplessPrefetchServiceProvider = Provider<GaplessPrefetchService>((ref) {
  return GaplessPrefetchService(ref);
});
