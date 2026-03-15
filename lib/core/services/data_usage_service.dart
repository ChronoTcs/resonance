import 'package:shared_preferences/shared_preferences.dart';

class DataUsageService {
  static final DataUsageService _instance = DataUsageService._internal();
  factory DataUsageService() => _instance;
  DataUsageService._internal();

  static const _totalBytesKey = 'total_data_usage_bytes';
  
  Future<int> getTotalBytes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalBytesKey) ?? 0;
  }

  Future<void> addBytes(int bytes) async {
    if (bytes <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalBytesKey) ?? 0;
    await prefs.setInt(_totalBytesKey, current + bytes);
  }

  Future<void> resetUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalBytesKey, 0);
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
