import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/core/services/media_cache_service.dart';

const _recentlyPlayedKey = 'recently_played_items';
const _maxRecentlyPlayed = 20;

final recentlyPlayedProvider = AsyncNotifierProvider<RecentlyPlayedNotifier, List<MediaItem>>(() {
  return RecentlyPlayedNotifier();
});

class RecentlyPlayedNotifier extends AsyncNotifier<List<MediaItem>> {

  @override
  Future<List<MediaItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_recentlyPlayedKey) ?? [];
    return jsonList.map((item) => MediaItem.fromJson(jsonDecode(item))).toList();
  }

  Future<void> addTrack(MediaItem item) async {
    final currentList = List<MediaItem>.from(state.value ?? []);

    // Remove duplicates based on ID or Path
    currentList.removeWhere((i) => 
      (i.id != null && i.id == item.id) || 
      (i.path == item.path)
    );

    // If local track with art, cache the art to disk so we can preserve it even after stripping bytes
    MediaItem itemToSave = item;
    if (item.albumArt != null && item.thumbnailUrl == null) {
      try {
        final cacheService = MediaCacheService();
        final songId = item.id ?? item.path.hashCode.toString();
        await cacheService.saveArtToCache(songId, item.albumArt!);
        final cachePath = await cacheService.getCachedArtPath(songId);
        if (cachePath != null) {
          itemToSave = item.copyWith(thumbnailUrl: cachePath);
        }
      } catch (e) {
        print('Error caching art in recently played: $e');
      }
    }

    // Add to the beginning
    currentList.insert(0, itemToSave);

    final updatedList = currentList.take(_maxRecentlyPlayed).toList();

    state = AsyncValue.data(updatedList);
    
    // Save to disk without heavy album art bytes to prevent UI freezes
    // Using the fixed copyWith to explicitly clear the art
    final listForStorage = updatedList.map((item) => item.copyWith(clearAlbumArt: true)).toList();
    await _saveState(listForStorage);
  }

  Future<void> _saveState(List<MediaItem> listToSave) async {
    final prefs = await SharedPreferences.getInstance();
    // Use the optimized toJson that skips art serialization
    final jsonList = listToSave.map((item) => jsonEncode(item.toJson(includeArt: false))).toList();
    await prefs.setStringList(_recentlyPlayedKey, jsonList);
  }
}
