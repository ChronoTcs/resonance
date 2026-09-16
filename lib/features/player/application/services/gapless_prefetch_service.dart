import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../providers/audio_provider.dart';
import '../services/queue_service.dart';
import '../services/stream_resolution_service.dart';
import 'playback_architecture_service.dart';

/// Proactively resolves and pre-caches the upcoming track (N+1) into local disk
/// so playback is gapless and consumes 0MB streaming data on transition.
///
/// Uses a 15-second stabilization delay after track starts to ensure the player's
/// initial demuxer buffer is 100% full before background downloading begins.
class GaplessPrefetchService {
  final Ref _ref;

  // Guardrail: prevent concurrent double-fetch per slot
  bool _isFetchingFirst = false;
  bool _isFetchingSecond = false;

  // 15-second stabilization timer for N+1 full audio pre-cache
  Timer? _stabilizationTimer;
  // Stagger timer for N+2 lightweight URL pre-warm
  Timer? _staggerTimer;

  GaplessPrefetchService(this._ref);

  /// Schedules N+1 disk pre-cache after 15s, and N+2 URL pre-warm after 20s.
  /// Safe to call on every track change — resetLock() clears prior timers.
  Future<void> proactiveFetch() async {
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      resetLock();
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
      final n2 = qs.peekTrackAt(currentState.currentIndex + 2);
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
  }

  /// Reset all locks and cancel timers on track change or skip.
  /// Prevents ghost downloads for old tracks when user rapidly advances queue.
  void resetLock() {
    _stabilizationTimer?.cancel();
    _stabilizationTimer = null;
    _staggerTimer?.cancel();
    _staggerTimer = null;
    _isFetchingFirst = false;
    _isFetchingSecond = false;
    debugPrint('[Gapless] Resetting prefetch locks and timers.');
  }
}

final gaplessPrefetchServiceProvider = Provider<GaplessPrefetchService>((ref) {
  return GaplessPrefetchService(ref);
});
