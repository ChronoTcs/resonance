import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/media_cache_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/stream_cache_tracker_service.dart';

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

    debugPrint('[MaintenanceService] Running 24h stream cache cleanup...');
    try {
      final tracker = _ref.read(streamCacheTrackerServiceProvider);
      final cache = _ref.read(mediaCacheServiceProvider);
      
      final expiredIds = await tracker.getExpiredIds(const Duration(days: 30));
      if (expiredIds.isNotEmpty) {
        for (var id in expiredIds) {
          await cache.removeFromCache(id);
        }
        await tracker.removeEntries(expiredIds);
        debugPrint('[MaintenanceService] Cleaned ${expiredIds.length} expired tracks.');
      }
      await prefs.setInt('last_stream_cleanup', now);
    } catch (e) {
      debugPrint('[MaintenanceService] Cleanup failed: $e');
    }
  }
}
