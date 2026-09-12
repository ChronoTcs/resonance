import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

const _maxRecentSearches = 20;

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<MediaItem>>(() {
  return RecentSearchesNotifier();
});

class RecentSearchesNotifier extends AsyncNotifier<List<MediaItem>> {
  Future<File> _getHistoryFile() async {
    final cacheManager = ref.read(cacheManagerProvider);
    final dir = await cacheManager.getBaseCacheDir();
    return File(p.join(dir.path, 'recent_searches.json'));
  }

  @override
  Future<List<MediaItem>> build() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];

      return await compute(_parseRecentSearchesJson, content);
    } catch (e) {
      debugPrint('[RecentSearchesNotifier] Failed to load search history: $e');
      return [];
    }
  }

  Future<void> addSearchTrack(MediaItem item) async {
    final currentList = List<MediaItem>.from(state.value ?? []);

    final targetId = item.id ?? item.path;
    currentList.removeWhere((i) => (i.id ?? i.path) == targetId);

    // Recent searches only tracks streaming items picked by user
    final cleanItem = item.copyWith(clearAlbumArt: true);
    currentList.insert(0, cleanItem);

    final updatedList = currentList.take(_maxRecentSearches).toList();
    state = AsyncValue.data(updatedList);

    await _saveState(updatedList);
  }

  Future<void> removeSearchTrack(String id) async {
    final currentList = List<MediaItem>.from(state.value ?? []);
    currentList.removeWhere((i) => (i.id ?? i.path) == id);

    state = AsyncValue.data(currentList);
    await _saveState(currentList);
  }

  Future<void> clearSearchHistory() async {
    state = const AsyncValue.data([]);
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[RecentSearchesNotifier] Failed to clear search history: $e');
    }
  }

  Future<void> _saveState(List<MediaItem> listToSave) async {
    try {
      final file = await _getHistoryFile();
      final cacheManager = ref.read(cacheManagerProvider);

      final jsonList =
          listToSave.map((item) => item.toJson(includeArt: false)).toList();
      final content = jsonEncode(jsonList);

      await cacheManager.synchronizedWrite(file, content);
    } catch (e) {
      debugPrint('[RecentSearchesNotifier] Failed to save search history: $e');
    }
  }
}

List<MediaItem> _parseRecentSearchesJson(String content) {
  try {
    final jsonList = jsonDecode(content) as List;
    return jsonList.map((j) => MediaItem.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}
