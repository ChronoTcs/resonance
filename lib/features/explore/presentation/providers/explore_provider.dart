import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import '../../data/repositories/youtube_search_repository.dart';
import '../../data/models/explore_item.dart';
import '../../data/models/explore_playlist.dart';
import '../../../player/application/providers/audio_provider.dart';
import '../../../library/data/models/media_item.dart';

// re-export from core so existing callers of explore_provider don't break
export 'package:resonance/core/providers/search_provider.dart'
    show searchQueryProvider, searchStateProvider, SearchQueryNotifier, SearchStateNotifier;
export 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';


import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import 'package:resonance/features/library/application/library_provider.dart';

final searchResultsProvider = FutureProvider<List<ExploreItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));
  if (!isOnline) {
    final cleanQuery = query.trim().toLowerCase();
    final libraryTracks = ref.read(libraryProvider).allMedia.where((m) => m.type == 'audio').toList();
    final cachedTracks = await ref.watch(cachedStreamMusicProvider.future);

    final combined = [...libraryTracks, ...cachedTracks];
    final seenIds = <String>{};
    final matches = <ExploreItem>[];

    for (final track in combined) {
      final id = track.id ?? track.path;
      if (seenIds.contains(id)) continue;

      final title = track.title.toLowerCase();
      final artist = (track.artist ?? '').toLowerCase();
      final album = (track.album ?? '').toLowerCase();

      if (title.contains(cleanQuery) || artist.contains(cleanQuery) || album.contains(cleanQuery)) {
        seenIds.add(id);
        final dur = track.duration;
        final durStr = dur != null
            ? '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}'
            : '';
        matches.add(ExploreItem(
          id: id,
          title: track.title,
          author: track.artist ?? 'Offline Music',
          album: track.album,
          duration: durStr,
          thumbnailUrl: track.thumbnailUrl ?? '',
          url: track.path,
          type: 'audio',
        ));
      }
    }
    return matches;
  }

  final repo = ref.read(youtubeSearchRepositoryProvider);
  final results = await repo.search(query);
  
  if (results.isNotEmpty) {
    Future.microtask(() {
      if (!ref.mounted) return;
      final items = results.map((e) => MediaItem(
        id: e.id,
        title: e.title,
        artist: e.author,
        album: e.album,
        thumbnailUrl: e.thumbnailUrl,
        path: e.id,
        type: 'audio',
      )).toList();
      ref.read(audioProvider.notifier).preloadTracks(items);
    });
  }
  
  return results;
});

final searchPlaylistResultsProvider = FutureProvider<List<ExplorePlaylist>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];

  final repo = ref.read(youtubeSearchRepositoryProvider);
  return repo.searchPlaylists(query);
});

class ExploreSearchTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final exploreSearchTabProvider = NotifierProvider<ExploreSearchTabNotifier, int>(ExploreSearchTabNotifier.new);

final featuredMusicProvider = FutureProvider<List<ExploreItem>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  final repo = ref.read(youtubeSearchRepositoryProvider);
  final results = await repo.getFeaturedMusic();
  
  if (results.isNotEmpty) {
    Future.microtask(() {
      final items = results.map((e) => MediaItem(
        id: e.id,
        title: e.title,
        artist: e.author,
        thumbnailUrl: e.thumbnailUrl,
        path: e.id,
        type: 'audio',
      )).toList();
      ref.read(audioProvider.notifier).preloadTracks(items);
    });
  }
  
  return results;
});


