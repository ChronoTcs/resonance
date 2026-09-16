import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../../../library/application/library_provider.dart';
import '../../../library/application/blocked_tracks_provider.dart';
import '../providers/audio_provider.dart';

/// 
/// Handles logic that determines "what array of tracks" should be sent to
/// the AudioNotifier based on specialized contexts (Sequential playback, Radio fallback).
class QueueOrchestrator {
  final Ref _ref;

  QueueOrchestrator(this._ref);

  /// Plays from a specific index in the given context.
  void playSequentialContext(MediaItem track, List<MediaItem> contextQueue) {
    final blocked = _ref.read(blockedTracksProvider.notifier);
    if (blocked.isBlocked(track.id, path: track.path)) return;

    final sanitizedQueue = contextQueue
        .where((t) => !blocked.isBlocked(t.id, path: t.path))
        .toList();
    if (sanitizedQueue.isEmpty) return;

    final notifier = _ref.read(audioProvider.notifier);
    
    // 1. Resolve index
    final trackId = track.id ?? track.path;
    final index = sanitizedQueue.indexWhere((t) => (t.id ?? t.path) == trackId);

    if (index != -1) {
      notifier.playPlaylist(sanitizedQueue, initialIndex: index);
    } else {
      notifier.playPlaylist([track]);
    }
  }

  /// Turns shuffle ON, places chosen track first, and fills the rest with random local tracks & cached streams.
  void playWithLocalRadioFallback(MediaItem track, List<MediaItem> allLocalTracks) {
    final blocked = _ref.read(blockedTracksProvider.notifier);
    if (blocked.isBlocked(track.id, path: track.path)) return;

    final notifier = _ref.read(audioProvider.notifier);

    // 1. Blend local library with cached stream music
    final cachedAsync = _ref.read(cachedStreamMusicProvider);
    final cachedTracks = cachedAsync.asData?.value ?? const <MediaItem>[];
    final combinedPool = [...allLocalTracks, ...cachedTracks];

    // 2. Deduplication & Blocked Filter
    final trackId = track.id ?? track.path;
    final seen = <String>{trackId};
    final filteredPool = <MediaItem>[];

    for (final t in combinedPool) {
      final tid = t.id ?? t.path;
      if (!seen.contains(tid) && !blocked.isBlocked(t.id, path: t.path)) {
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

  /// Plays an offline radio queue when online playback fails or runs out of songs.
  /// If [failedTrack] is provided, it is excluded so unplayable tracks are not retried.
  void playOfflineRadioFallback({
    MediaItem? failedTrack,
    List<MediaItem>? localTracks,
    List<MediaItem>? cachedTracks,
  }) {
    final blocked = _ref.read(blockedTracksProvider.notifier);
    final notifier = _ref.read(audioProvider.notifier);

    // 1. Blend local library with cached stream music
    final allLocal = localTracks ?? _ref.read(libraryProvider).allMedia;
    final allCached = cachedTracks ??
        _ref.read(cachedStreamMusicProvider).asData?.value ??
        const <MediaItem>[];
    final combinedPool = [...allLocal, ...allCached];

    // 2. Deduplication & Blocked Filter
    final seen = <String>{};
    if (failedTrack != null) {
      seen.add(failedTrack.id ?? failedTrack.path);
    }
    final filteredPool = <MediaItem>[];

    for (final t in combinedPool) {
      final tid = t.id ?? t.path;
      if (!seen.contains(tid) && !blocked.isBlocked(t.id, path: t.path)) {
        seen.add(tid);
        filteredPool.add(t);
      }
    }

    if (filteredPool.isEmpty) return;

    // Shuffle offline pool
    filteredPool.shuffle();

    notifier.setShuffle(true);
    notifier.playPlaylist(filteredPool, initialIndex: 0);
  }
}

final queueOrchestratorProvider = Provider<QueueOrchestrator>((ref) {
  return QueueOrchestrator(ref);
});
