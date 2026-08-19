import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/services/data_usage_service.dart';
import '../../../core/data/services/media_cache_service.dart';
import '../../../core/data/services/storage_service.dart';
import '../../player/application/services/playback_architecture_service.dart';

class MaintenanceState {
  final String cacheSize;
  final Map<String, int> folderSizes;
  final int totalDataUsage;
  final bool isLoading;

  MaintenanceState({
    this.cacheSize = '0 B',
    this.folderSizes = const {},
    this.totalDataUsage = 0,
    this.isLoading = false,
  });

  MaintenanceState copyWith({
    String? cacheSize,
    Map<String, int>? folderSizes,
    int? totalDataUsage,
    bool? isLoading,
  }) {
    return MaintenanceState(
      cacheSize: cacheSize ?? this.cacheSize,
      folderSizes: folderSizes ?? this.folderSizes,
      totalDataUsage: totalDataUsage ?? this.totalDataUsage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MaintenanceNotifier extends Notifier<MaintenanceState> {
  @override
  MaintenanceState build() {
    // 0ms instant initialization from persisted snapshot
    Map<String, int> initialFolderSizes = const {};
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final savedJson = prefs.getString('cached_storage_sizes');
      if (savedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedJson);
        final Map<String, int> parsed = {};
        decoded.forEach((key, value) {
          if (value is int) parsed[key] = value;
        });
        initialFolderSizes = parsed;
      }
    } catch (_) {}

    Future.microtask(() => refresh());
    return MaintenanceState(folderSizes: initialFolderSizes);
  }

  DataUsageService get _dataUsageService => ref.read(dataUsageServiceProvider);
  MediaCacheService get _mediaCacheService => ref.read(mediaCacheServiceProvider);

  Future<void> refresh({bool force = false}) async {
    if (state.folderSizes.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    final size = await _mediaCacheService.getCacheSize(force: force);
    final detailedSizes = await _mediaCacheService.getDetailedCacheSizes(force: force);
    final usage = await _dataUsageService.getTotalBytes();
    state = state.copyWith(
      cacheSize: size, 
      folderSizes: detailedSizes,
      totalDataUsage: usage, 
      isLoading: false,
    );
  }

  Future<void> forceRecalculate() async {
    await refresh(force: true);
  }

  Future<void> clearCategory(String category) async {
    state = state.copyWith(isLoading: true);
    if (category == 'all') {
      ref.read(playbackArchitectureServiceProvider).clearCache();
      await _mediaCacheService.clearCategory('local_music');
      await _mediaCacheService.clearCategory('local_lyrics');
      await _mediaCacheService.clearCategory('local_images');
      await _mediaCacheService.clearCategory('stream_audio');
      await _mediaCacheService.clearCategory('stream_images');
      await _mediaCacheService.clearCategory('stream_lyrics');
      await _mediaCacheService.clearCategory('metadata');
      await _mediaCacheService.clearCategory('translate');
      await _mediaCacheService.clearCategory('images');
    } else if (category == 'group_local') {
      await _mediaCacheService.clearCategory('local_music');
      await _mediaCacheService.clearCategory('local_lyrics');
      await _mediaCacheService.clearCategory('local_images');
    } else if (category == 'group_stream') {
      ref.read(playbackArchitectureServiceProvider).clearCache();
      await _mediaCacheService.clearCategory('stream_audio');
      await _mediaCacheService.clearCategory('stream_images');
      await _mediaCacheService.clearCategory('stream_lyrics');
    } else if (category == 'group_system') {
      await _mediaCacheService.clearCategory('metadata');
      await _mediaCacheService.clearCategory('translate');
      await _mediaCacheService.clearCategory('images');
    } else {
      await _mediaCacheService.clearCategory(category);
    }
    await refresh();
  }

  Future<void> clearCache() async {
    await clearCategory('all');
  }

  Future<void> resetDataUsage() async {
    state = state.copyWith(isLoading: true);
    await _dataUsageService.resetUsage();
    await refresh();
  }

  String formatBytes(int bytes) {
    return _dataUsageService.formatBytes(bytes);
  }
}

final maintenanceProvider = NotifierProvider<MaintenanceNotifier, MaintenanceState>(() {
  return MaintenanceNotifier();
});

// ── Cache Config Providers (backed by SharedPreferences) ─────────────────────

class StreamCacheLimitGbNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt('stream_cache_limit_gb') ?? 10; // Default: 10 GB
  }

  void setLimitGb(int limitGb) {
    state = limitGb;
    ref.read(sharedPreferencesProvider).setInt('stream_cache_limit_gb', limitGb);
  }
}

final streamCacheLimitGbProvider = NotifierProvider<StreamCacheLimitGbNotifier, int>(() {
  return StreamCacheLimitGbNotifier();
});

class StreamTrackRetentionDaysNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt('stream_track_retention_days') ?? 30; // Default: 30 days
  }

  void setDays(int days) {
    state = days;
    ref.read(sharedPreferencesProvider).setInt('stream_track_retention_days', days);
  }
}

final streamTrackRetentionDaysProvider = NotifierProvider<StreamTrackRetentionDaysNotifier, int>(() {
  return StreamTrackRetentionDaysNotifier();
});

class SecondaryCacheRetentionDaysNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt('secondary_cache_retention_days') ?? 7; // Default: 7 days
  }

  void setDays(int days) {
    state = days;
    ref.read(sharedPreferencesProvider).setInt('secondary_cache_retention_days', days);
  }
}

final secondaryCacheRetentionDaysProvider = NotifierProvider<SecondaryCacheRetentionDaysNotifier, int>(() {
  return SecondaryCacheRetentionDaysNotifier();
});
