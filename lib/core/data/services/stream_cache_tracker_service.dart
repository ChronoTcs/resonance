import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cache_manager.dart';

final streamCacheTrackerServiceProvider = Provider<StreamCacheTrackerService>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return StreamCacheTrackerService(cacheManager);
});

class StreamCacheTrackerService {
  final CacheManager _cacheManager;
  final String _dbName = 'stream_cache_tracker.json';
  
  StreamCacheTrackerService(this._cacheManager);

  Future<File> get _dbFile async {
    final metaDir = await _cacheManager.getBaseCacheDir();
    return File(p.join(metaDir.path, _dbName));
  }

  /// Updates the last played timestamp for a specific ID.
  Future<void> updateLastPlayed(String id) async {
    try {
      final file = await _dbFile;
      Map<String, dynamic> data = {};

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          data = jsonDecode(content) as Map<String, dynamic>;
        }
      }

      data[id] = DateTime.now().toIso8601String();
      await _cacheManager.synchronizedWrite(file, jsonEncode(data));
      debugPrint('StreamCacheTracker: Updated timestamp for $id');
    } catch (e) {
      debugPrint('StreamCacheTracker Error: $e');
    }
  }

  /// Gets list of expired IDs (e.g., > 30 days).
  Future<List<String>> getExpiredIds(Duration threshold) async {
    try {
      final file = await _dbFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final data = jsonDecode(content) as Map<String, dynamic>;
      final now = DateTime.now();
      final List<String> expired = [];

      data.forEach((id, timestamp) {
        try {
          final lastPlayed = DateTime.parse(timestamp);
          if (now.difference(lastPlayed) > threshold) {
            expired.add(id);
          }
        } catch (_) {}
      });

      return expired;
    } catch (e) {
      debugPrint('StreamCacheTracker getExpiredIds Error: $e');
      return [];
    }
  }

  /// Menghapus entry dari database setelah file fisiknya dibersihkan.
  Future<void> removeEntries(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      final file = await _dbFile;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      for (var id in ids) {
        data.remove(id);
      }

      await _cacheManager.synchronizedWrite(file, jsonEncode(data));
    } catch (_) {}
  }
}
