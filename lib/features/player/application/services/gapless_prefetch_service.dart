import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../services/queue_service.dart';
import '../services/stream_resolution_service.dart';

/// 
/// Triggered reactively by AudioOrchestrator when current track duration is near end.
class GaplessPrefetchService {
  final Ref _ref;
  
  // Guardrail 1: The Gapless Spam Guard
  bool _isFetching = false;

  GaplessPrefetchService(this._ref);

  /// Proactively fetches the next track and appends it to the MediaKit playlist.
  Future<void> proactiveFetch() async {
    if (_isFetching) return;

    final audioState = _ref.read(audioProvider);
    final queueService = _ref.read(queueServiceProvider);
    
    // Get the next track in current queue
    final nextTrack = queueService.peekNextTrack(
      audioState.loopMode,
      audioState.isShuffleEnabled,
    );

    if (nextTrack == null || !nextTrack.isStreaming) return;

    _isFetching = true;
    debugPrint('[Gapless] JIT Prefetching (TTL Safe): ${nextTrack.title}');

    try {
      final resolver = _ref.read(streamResolutionServiceProvider);
      
      // Pre-resolve stream URL into cache so player.open() starts instantly on track change
      await resolver.resolve(nextTrack);
      
      debugPrint('[Gapless] Next track pre-resolved into cache: ${nextTrack.title}');
    } catch (e) {
      debugPrint('[Gapless] JIT Prefetch failed: $e');
      _isFetching = false;
    }
  }

  /// Reset the fetch lock. Called by AudioOrchestrator on track change.
  void resetLock() {
    if (_isFetching) {
      debugPrint('[Gapless] Resetting pre-fetch lock.');
      _isFetching = false;
    }
  }
}

final gaplessPrefetchServiceProvider = Provider<GaplessPrefetchService>((ref) {
  return GaplessPrefetchService(ref);
});
