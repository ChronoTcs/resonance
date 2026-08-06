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
    // We can't call async refresh here directly if we want initial state to be empty,
    // but we can use Future.microtask or just let the UI call refresh.
    // Or we can return an initial state and trigger a refresh.
    Future.microtask(() => refresh());
    return MaintenanceState();
  }

  DataUsageService get _dataUsageService => ref.read(dataUsageServiceProvider);
  MediaCacheService get _mediaCacheService => ref.read(mediaCacheServiceProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final size = await _mediaCacheService.getCacheSize();
    final detailedSizes = await _mediaCacheService.getDetailedCacheSizes();
    final usage = await _dataUsageService.getTotalBytes();
    state = state.copyWith(
      cacheSize: size, 
      folderSizes: detailedSizes,
      totalDataUsage: usage, 
      isLoading: false,
    );
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
