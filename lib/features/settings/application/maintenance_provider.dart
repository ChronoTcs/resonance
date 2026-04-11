import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/services/data_usage_service.dart';
import '../../../core/data/services/media_cache_service.dart';
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
    }
    await _mediaCacheService.clearCategory(category);
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
