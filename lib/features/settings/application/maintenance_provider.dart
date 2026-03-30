import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/data_usage_service.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../player/application/playback_architecture_service.dart';

class MaintenanceState {
  final String cacheSize;
  final int totalDataUsage;
  final bool isLoading;

  MaintenanceState({
    this.cacheSize = '0 B',
    this.totalDataUsage = 0,
    this.isLoading = false,
  });

  MaintenanceState copyWith({
    String? cacheSize,
    int? totalDataUsage,
    bool? isLoading,
  }) {
    return MaintenanceState(
      cacheSize: cacheSize ?? this.cacheSize,
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
    final usage = await _dataUsageService.getTotalBytes();
    state = state.copyWith(cacheSize: size, totalDataUsage: usage, isLoading: false);
  }

  Future<void> clearCache() async {
    state = state.copyWith(isLoading: true);
    // Clear psychological/in-memory cache
    ref.read(playbackArchitectureServiceProvider).clearCache();
    // Clear physical files
    await _mediaCacheService.clearCache();
    await refresh();
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
