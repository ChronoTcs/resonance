import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/youtube_service.dart';
import '../../../player/application/audio_provider.dart';
import '../../../library/data/models/media_item.dart';

// youtubeServiceProvider is now defined in features/explore/data/services/youtube_service.dart

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

  final service = ref.read(youtubeServiceProvider);
  final results = await service.search(query);
  
  // Predictive: Pre-fetch URLs for the first few search results
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

final FutureProvider<List<ExploreItem>> featuredMusicProvider = FutureProvider<List<ExploreItem>>((ref) async {
  final service = ref.read(youtubeServiceProvider);
  final results = await service.getFeaturedMusic();
  
  // Predictive: Pre-fetch URLs for featured tracks
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
