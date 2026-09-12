import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../providers/audio_provider.dart';

/// 
/// Handles logic that determines "what array of tracks" should be sent to
/// the AudioNotifier based on specialized contexts (Sequential playback, Radio fallback).
class QueueOrchestrator {
  final Ref _ref;

  QueueOrchestrator(this._ref);

  /// Plays from a specific index in the given context.
  void playSequentialContext(MediaItem track, List<MediaItem> contextQueue) {
    final notifier = _ref.read(audioProvider.notifier);
    
    // 1. Resolve index
    final trackId = track.id ?? track.path;
    final index = contextQueue.indexWhere((t) => (t.id ?? t.path) == trackId);

    if (index != -1) {
      notifier.playPlaylist(contextQueue, initialIndex: index);
    } else {
      notifier.playPlaylist([track]);
    }
  }

  /// Turns shuffle ON, places chosen track first, and fills the rest with random local tracks & cached streams.
  void playWithLocalRadioFallback(MediaItem track, List<MediaItem> allLocalTracks) {
    final notifier = _ref.read(audioProvider.notifier);

    // 1. Blend local library with cached stream music
    final cachedAsync = _ref.read(cachedStreamMusicProvider);
    final cachedTracks = cachedAsync.asData?.value ?? const <MediaItem>[];
    final combinedPool = [...allLocalTracks, ...cachedTracks];

    // 2. Deduplication
    final trackId = track.id ?? track.path;
    final seen = <String>{trackId};
    final filteredPool = <MediaItem>[];

    for (final t in combinedPool) {
      final tid = t.id ?? t.path;
      if (!seen.contains(tid)) {
        seen.add(tid);
        filteredPool.add(t);
      }
    }

    // 3. Construct Queue: [Selected] + [Remaining Offline Pool]
    final radioQueue = [track, ...filteredPool];

    // 4. Force Shuffle ON and play from start
    notifier.setShuffle(true);
    notifier.playPlaylist(radioQueue, initialIndex: 0);
  }
}

final queueOrchestratorProvider = Provider<QueueOrchestrator>((ref) {
  return QueueOrchestrator(ref);
});
