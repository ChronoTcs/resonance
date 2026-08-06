import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/storage_service.dart';

class SearchHistoryNotifier extends Notifier<List<String>> {
  static const String _key = 'explore_search_history';

  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final rawJson = prefs.getString(_key);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawJson);
        return List<String>.from(list.map((e) => e.toString()));
      } catch (_) {}
    }
    return const [];
  }

  void addQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final filtered = state.where((q) => q.toLowerCase() != trimmed.toLowerCase()).toList();
    final newList = [trimmed, ...filtered].take(10).toList();
    state = List<String>.from(newList);
    _save(newList);
  }

  void removeQuery(String query) {
    final newList = state.where((q) => q != query).toList();
    state = List<String>.from(newList);
    _save(newList);
  }

  void clearAll() {
    state = const [];
    _save(const []);
  }

  Future<void> _save(List<String> list) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, jsonEncode(list));
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(() {
  return SearchHistoryNotifier();
});
