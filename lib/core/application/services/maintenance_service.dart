import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/cache_manager.dart';
import '../../data/services/media_cache_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/stream_cache_tracker_service.dart';
import '../../../features/settings/application/maintenance_provider.dart';

final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  return MaintenanceService(ref);
});

class MaintenanceService {
  final Ref _ref;
  MaintenanceService(this._ref);

  /// Performs periodic maintenance tasks such as cleaning up old stream cache.
  Future<void> runDailyCleanup() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final lastCleanup = prefs.getInt('last_stream_cleanup') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Only run once every 24 hours
    if (now - lastCleanup < 24 * 60 * 60 * 1000) return;

    final retentionDays = _ref.read(streamTrackRetentionDaysProvider);
    debugPrint('[MaintenanceService] Running 24h stream cache cleanup (retention: ${retentionDays}d)...');
    try {
      final tracker = _ref.read(streamCacheTrackerServiceProvider);
      final cache = _ref.read(mediaCacheServiceProvider);
      final cacheManager = _ref.read(cacheManagerProvider);

      Set<String> pinnedIds = const {};
      try {
        final raw = prefs.getString('pinned_stream_ids');
        if (raw != null) {
          pinnedIds = Set<String>.from(jsonDecode(raw) as List);
        }
      } catch (_) {}

      final expiredIds = await tracker.getExpiredIds(Duration(days: retentionDays));
      final evictableIds = expiredIds.where((id) {
        final safeId = cache.getSafeFilename(id);
        return !pinnedIds.contains(id) && !pinnedIds.contains(safeId);
      }).toList();

      if (evictableIds.isNotEmpty) {
        for (var id in evictableIds) {
          await cache.removeFromCache(id);
        }
        await tracker.removeEntries(evictableIds);
        debugPrint('[MaintenanceService] Cleaned ${evictableIds.length} expired tracks (audio + art + lyrics + metadata).');
      }

      await cacheManager.cleanupTemporaryStreams(
        maxAgeDays: retentionDays,
        pinnedIds: pinnedIds,
      );

      await prefs.setInt('last_stream_cleanup', now);
    } catch (e) {
      debugPrint('[MaintenanceService] Cleanup failed: $e');
    }
  }
}
