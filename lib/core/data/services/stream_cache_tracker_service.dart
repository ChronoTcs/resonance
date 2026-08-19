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

  /// Updates the last played timestamp and increments play count for a specific ID.
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

      int currentCount = 0;
      if (data[id] is Map) {
        currentCount = (data[id]['playCount'] as num?)?.toInt() ?? 0;
      } else if (data[id] is String) {
        currentCount = 1;
      }

      data[id] = {
        'lastPlayed': DateTime.now().toIso8601String(),
        'playCount': currentCount + 1,
      };

      await _cacheManager.synchronizedWrite(file, jsonEncode(data));
      debugPrint('[StreamCacheTracker] Updated timestamp & count (${currentCount + 1}) for $id');
    } catch (e) {
      debugPrint('[StreamCacheTracker] Error: $e');
    }
  }

  /// Gets top played video IDs sorted by play count descending.
  Future<List<String>> getTopPlayedIds({int limit = 10, Duration? withinDuration}) async {
    try {
      final file = await _dbFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final data = jsonDecode(content) as Map<String, dynamic>;
      final now = DateTime.now();

      final entries = <MapEntry<String, int>>[];
      data.forEach((id, val) {
        int count = 1;
        DateTime? lastPlayed;
        if (val is Map) {
          count = (val['playCount'] as num?)?.toInt() ?? 1;
          if (val['lastPlayed'] != null) {
            lastPlayed = DateTime.tryParse(val['lastPlayed'] as String);
          }
        } else if (val is String) {
          lastPlayed = DateTime.tryParse(val);
        }

        if (withinDuration != null && lastPlayed != null) {
          if (now.difference(lastPlayed) > withinDuration) return;
        }
        entries.add(MapEntry(id, count));
      });

      entries.sort((a, b) => b.value.compareTo(a.value));
      return entries.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('[StreamCacheTracker] getTopPlayedIds Error: $e');
      return [];
    }
  }

  /// Gets songs with high historical play counts not played recently (e.g. > 30 days).
  Future<List<String>> getForgottenFavoriteIds({
    int minPlayCount = 2,
    Duration inactiveThreshold = const Duration(days: 30),
    int limit = 10,
  }) async {
    try {
      final file = await _dbFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final data = jsonDecode(content) as Map<String, dynamic>;
      final now = DateTime.now();

      final candidates = <MapEntry<String, int>>[];
      data.forEach((id, val) {
        int count = 0;
        DateTime? lastPlayed;
        if (val is Map) {
          count = (val['playCount'] as num?)?.toInt() ?? 0;
          if (val['lastPlayed'] != null) {
            lastPlayed = DateTime.tryParse(val['lastPlayed'] as String);
          }
        } else if (val is String) {
          count = 1;
          lastPlayed = DateTime.tryParse(val);
        }

        if (count >= minPlayCount && lastPlayed != null) {
          if (now.difference(lastPlayed) >= inactiveThreshold) {
            candidates.add(MapEntry(id, count));
          }
        }
      });

      candidates.sort((a, b) => b.value.compareTo(a.value));
      return candidates.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('[StreamCacheTracker] getForgottenFavoriteIds Error: $e');
      return [];
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

      data.forEach((id, val) {
        try {
          String? timestamp;
          if (val is String) {
            timestamp = val;
          } else if (val is Map) {
            timestamp = val['lastPlayed'] as String?;
          }
          if (timestamp != null) {
            final lastPlayed = DateTime.parse(timestamp);
            if (now.difference(lastPlayed) > threshold) {
              expired.add(id);
            }
          }
        } catch (_) {}
      });

      return expired;
    } catch (e) {
      debugPrint('[StreamCacheTracker] getExpiredIds Error: $e');
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
