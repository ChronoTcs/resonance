import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/core/data/services/cache_manager.dart';

const _maxRecentlyPlayed = 20;

final recentlyPlayedProvider = AsyncNotifierProvider<RecentlyPlayedNotifier, List<MediaItem>>(() {
  return RecentlyPlayedNotifier();
});

class RecentlyPlayedNotifier extends AsyncNotifier<List<MediaItem>> {
  Future<File> _getHistoryFile() async {
    final cacheManager = ref.read(cacheManagerProvider);
    final dir = await cacheManager.getBaseCacheDir();
    return File(p.join(dir.path, 'recently_played.json'));
  }

  @override
  Future<List<MediaItem>> build() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];

      // Use compute for JSON parsing to avoid blocking UI thread
      return await compute(_parseRecentlyPlayedJson, content);
    } catch (e) {
      debugPrint('RecentlyPlayedNotifier: Failed to load history: $e');
      return [];
    }
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
        final cacheService = ref.read(mediaCacheServiceProvider);
        final songId = item.id ?? item.path.hashCode.toString();
        await cacheService.saveArtToCache(songId, item.albumArt!);
        final cachePath = await cacheService.getCachedArtPath(songId);
        if (cachePath != null) {
          itemToSave = item.copyWith(thumbnailUrl: cachePath);
        }
      } catch (e) {
        debugPrint('Error caching art in recently played: $e');
      }
    }

    // Add to the beginning
    currentList.insert(0, itemToSave);

    final updatedList = currentList.take(_maxRecentlyPlayed).toList();

    state = AsyncValue.data(updatedList);
    
    // Save to disk without heavy album art bytes to prevent UI freezes
    final listForStorage = updatedList.map((item) => item.copyWith(clearAlbumArt: true)).toList();
    await _saveState(listForStorage);
  }

  Future<void> clearHistory() async {
    state = const AsyncValue.data([]);
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('RecentlyPlayedNotifier: Failed to clear history file: $e');
    }
  }

  Future<void> _saveState(List<MediaItem> listToSave) async {
    try {
      final file = await _getHistoryFile();
      final cacheManager = ref.read(cacheManagerProvider);
      
      final jsonList = listToSave.map((item) => item.toJson(includeArt: false)).toList();
      final content = jsonEncode(jsonList);
      
      await cacheManager.synchronizedWrite(file, content);
    } catch (e) {
      debugPrint('RecentlyPlayedNotifier: Failed to save history: $e');
    }
  }
}

/// Isolate-safe JSON parser for Recently Played
List<MediaItem> _parseRecentlyPlayedJson(String jsonString) {
  try {
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((item) => MediaItem.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('RecentlyPlayed Isolate: Failed to parse JSON: $e');
    return [];
  }
}
