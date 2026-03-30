import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/services/cache_manager.dart';

class TranslationCacheCleanup {
  static Future<void> cleanup(CacheManager cacheManager) async {
    try {
      final translateDir = await cacheManager.getTranslateDir();
      if (!await translateDir.exists()) return;

      final now = DateTime.now();
      final maxAge = const Duration(days: 30);
      int deletedCount = 0;

      await for (final entity in translateDir.list(recursive: false)) {
        if (entity is File && entity.path.endsWith('.lrc')) {
          try {
            final stat = await entity.stat();
            // We use modified time as a proxy for 'last accessed' since we update it 
            // every time the translation is used.
            if (now.difference(stat.modified) > maxAge) {
              await entity.delete();
              deletedCount++;
            }
          } catch (e) {
            debugPrint('TranslationCacheCleanup: Failed to check/delete ${entity.path}: $e');
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('TranslationCacheCleanup: Deleted $deletedCount expired translation files.');
      }
    } catch (e) {
      debugPrint('TranslationCacheCleanup: Cleanup failed - $e');
    }
  }
}
