import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../services/queue_service.dart';
import '../services/stream_resolution_service.dart';

/// Proactively resolves the next 2 stream tracks into cache so
/// playback is gapless even if the user skips.
///
/// Triggered by AudioOrchestrator at T+5s after each track starts.
/// resetLock() must be called on every track change to re-arm the service
/// and cancel any pending stagger timer.
class GaplessPrefetchService {
  final Ref _ref;

  // Guardrail: prevent concurrent double-fetch per slot
  bool _isFetchingFirst = false;
  bool _isFetchingSecond = false;

  // Stagger timer for N+2 fetch — cancelled on track change
  Timer? _staggerTimer;

  GaplessPrefetchService(this._ref);

  /// Fetches N+1 immediately, then N+2 after a 5-second stagger.
  /// Safe to call multiple times — guards prevent duplicate requests.
  Future<void> proactiveFetch() async {
    final audioState = _ref.read(audioProvider);
    final queueService = _ref.read(queueServiceProvider);

    // ── Slot 1: N+1 ────────────────────────────────────────────────────────
    if (!_isFetchingFirst) {
      final next1 = queueService.peekNextTrack(
        audioState.loopMode,
        audioState.isShuffleEnabled,
      );

      if (next1 != null && next1.isStreaming) {
        _isFetchingFirst = true;
        debugPrint('[Gapless] Prefetching N+1: ${next1.title}');
        try {
          final resolver = _ref.read(streamResolutionServiceProvider);
          await resolver.resolve(next1);
          debugPrint('[Gapless] N+1 pre-resolved: ${next1.title}');
        } catch (e) {
          debugPrint('[Gapless] N+1 prefetch failed: $e');
        }
      }
    }

    // ── Slot 2: N+2 after 5s stagger ───────────────────────────────────────
    if (!_isFetchingSecond) {
      _staggerTimer?.cancel();
      _staggerTimer = Timer(const Duration(seconds: 5), () async {
        if (_isFetchingSecond) return;

        // Re-read state at timer fire time (track may have changed)
        final currentState = _ref.read(audioProvider);
        final qs = _ref.read(queueServiceProvider);

        final n2 = qs.peekTrackAt(currentState.currentIndex + 2);
        if (n2 == null || !n2.isStreaming) return;

        _isFetchingSecond = true;
        debugPrint('[Gapless] Prefetching N+2: ${n2.title}');
        try {
          final resolver = _ref.read(streamResolutionServiceProvider);
          await resolver.resolve(n2);
          debugPrint('[Gapless] N+2 pre-resolved: ${n2.title}');
        } catch (e) {
          debugPrint('[Gapless] N+2 prefetch failed: $e');
        }
      });
    }
  }

  /// Reset all locks. Called by AudioOrchestrator on every track change.
  /// Cancels the N+2 stagger timer to prevent ghost fetches for old tracks.
  void resetLock() {
    if (_isFetchingFirst || _isFetchingSecond || _staggerTimer != null) {
      debugPrint('[Gapless] Resetting prefetch locks.');
    }
    _isFetchingFirst = false;
    _isFetchingSecond = false;
    _staggerTimer?.cancel();
    _staggerTimer = null;
  }
}

final gaplessPrefetchServiceProvider = Provider<GaplessPrefetchService>((ref) {
  return GaplessPrefetchService(ref);
});
