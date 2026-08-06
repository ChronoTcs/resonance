import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/search_provider.dart';
import '../../data/repositories/youtube_search_repository.dart';
import '../../data/models/explore_item.dart';
import '../../data/models/explore_playlist.dart';
import '../../data/models/explore_home.dart';
import '../../../player/application/providers/audio_provider.dart';
import '../../../library/data/models/media_item.dart';

// ponytail: re-export from core so existing callers of explore_provider don't break
export 'package:resonance/core/providers/search_provider.dart'
    show searchQueryProvider, searchStateProvider, SearchQueryNotifier, SearchStateNotifier;

final homeFeedProvider = FutureProvider<List<ExploreHomeSection>>((ref) async {
  final repo = ref.read(youtubeSearchRepositoryProvider);
  return repo.getHomeFeed();
});


final searchResultsProvider = FutureProvider<List<ExploreItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

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
