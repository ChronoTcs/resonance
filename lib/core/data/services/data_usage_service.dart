import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

final dataUsageServiceProvider = Provider<DataUsageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DataUsageService(prefs);
});

class DataUsageService {
  final SharedPreferences _prefs;
  DataUsageService(this._prefs);

  static const _totalBytesKey = 'total_data_usage_bytes';
  
  // Buffered writing to prevent excessive disk I/O
  int _bufferedBytes = 0;
  static const int _flushThreshold = 1024 * 1024; // 1MB threshold

  Future<int> getTotalBytes() async {
    final stored = _prefs.getInt(_totalBytesKey) ?? 0;
    return stored + _bufferedBytes;
  }

  void addBytes(int bytes) {
    if (bytes <= 0) return;
    _bufferedBytes += bytes;
    
    // Auto-flush if threshold is reached
    if (_bufferedBytes >= _flushThreshold) {
      flush();
    }
  }

  Future<void> flush() async {
    if (_bufferedBytes == 0) return;
    
    final toFlush = _bufferedBytes;
    final current = _prefs.getInt(_totalBytesKey) ?? 0;
    await _prefs.setInt(_totalBytesKey, current + toFlush);
    _bufferedBytes = 0;
    debugPrint('[DataUsage] Flushed $toFlush bytes to disk.');
  }

  Future<void> resetUsage() async {
    _bufferedBytes = 0;
    await _prefs.setInt(_totalBytesKey, 0);
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
