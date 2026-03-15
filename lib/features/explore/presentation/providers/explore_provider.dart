import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/youtube_service.dart';

final youtubeServiceProvider = Provider((ref) {
  final service = YoutubeService();
  ref.onDispose(() => service.dispose());
  return service;
});

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
  return results;
});

final featuredPlaylistsProvider = FutureProvider<List<ExploreItem>>((ref) async {
  final service = ref.read(youtubeServiceProvider);
  return await service.getFeaturedPlaylists();
});
