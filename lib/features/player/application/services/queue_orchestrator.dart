import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Turns shuffle ON, places chosen track first, and fills the rest with random local tracks.
  void playWithLocalRadioFallback(MediaItem track, List<MediaItem> allLocalTracks) {
    final notifier = _ref.read(audioProvider.notifier);

    // 1. Deduplication
    final trackId = track.id ?? track.path;
    final filteredLocal = allLocalTracks
        .where((t) => (t.id ?? t.path) != trackId)
        .toList();

    // 2. Construct Queue: [Selected] + [Remaining Local]
    final radioQueue = [track, ...filteredLocal];

    // 3. Force Shuffle ON and play from start
    notifier.setShuffle(true);
    notifier.playPlaylist(radioQueue, initialIndex: 0);
  }
}

final queueOrchestratorProvider = Provider<QueueOrchestrator>((ref) {
  return QueueOrchestrator(ref);
});
