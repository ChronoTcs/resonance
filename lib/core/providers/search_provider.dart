import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global search query — shared between TopNavigationHeader search bar and ExploreScreen.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());

/// Whether an online search is in-flight.
class SearchStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setSearching(bool isSearching) => state = isSearching;
}

final searchStateProvider =
    NotifierProvider<SearchStateNotifier, bool>(() => SearchStateNotifier());
