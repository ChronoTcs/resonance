import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/application/services/playlist_stream_cache_handler.dart';

final playlistAutoCacheProvider =
    NotifierProvider<PlaylistAutoCacheNotifier, Set<String>>(() {
  return PlaylistAutoCacheNotifier();
});

class PlaylistAutoCacheNotifier extends Notifier<Set<String>> {
  static const String _key = 'playlist_auto_cache_offline_ids';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final list = prefs.getStringList(_key) ?? const [];
    return list.toSet();
  }

  bool isAutoCacheEnabled(String playlistId) => state.contains(playlistId);

  Future<void> toggleAutoCache(String playlistId) async {
    final next = Set<String>.from(state);
    final wasEnabled = next.contains(playlistId);
    if (wasEnabled) {
      next.remove(playlistId);
    } else {
      next.add(playlistId);
    }

    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
    state = next;

    final handler = ref.read(playlistStreamCacheHandlerProvider);
    if (!wasEnabled) {
      // Newly enabled: enqueue uncached tracks to idle worker
      await handler.cachePlaylistNow(playlistId);
    } else {
      // Disabled: remove pending tracks of this playlist from idle worker
      handler.cancelPlaylistCache(playlistId);
    }
  }
}

/// Computes the number of uncached streaming tracks in a specific playlist.
final playlistUncachedCountProvider =
    FutureProvider.family<int, String>((ref, playlistId) async {
  final playlistsState = ref.watch(playlistProvider);
  final playlist = playlistsState.value?.getById(playlistId);
  if (playlist == null) return 0;

  final cacheService = ref.watch(mediaCacheServiceProvider);
  int uncached = 0;
  for (final track in playlist.tracks) {
    if (!track.isStreaming) continue;
    final id = track.id ?? track.path;
    if (id.isEmpty) continue;
    final cached = await cacheService.getCachedAudioPath(id);
    if (cached == null) uncached++;
  }
  return uncached;
});
