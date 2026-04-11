import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/youtube_search_repository.dart';
import '../../data/models/explore_item.dart';
import '../../../player/application/providers/audio_provider.dart';
import '../../../library/data/models/media_item.dart';

class SearchStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setSearching(bool isSearching) => state = isSearching;
}
final searchStateProvider = NotifierProvider<SearchStateNotifier, bool>(() => SearchStateNotifier());

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());

final searchResultsProvider = FutureProvider<List<ExploreItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final repo = ref.read(youtubeSearchRepositoryProvider);
  final results = await repo.search(query);
  
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
