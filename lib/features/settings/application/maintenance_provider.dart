import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/application/services/network_connectivity_service.dart';
import '../../../core/data/services/data_usage_service.dart';
import '../../../core/data/services/media_cache_service.dart';
import '../../../core/data/services/storage_service.dart';
import '../../../core/providers/cached_stream_music_provider.dart';
import '../../download/application/providers/download_provider.dart';
import '../../home/presentation/providers/home_feed_provider.dart';
import '../../home/presentation/providers/recently_played_provider.dart';
import '../../library/application/library_provider.dart';
import '../../lyrics/application/lyrics_provider.dart';
import '../../lyrics/application/lyrics_translation_provider.dart';
import '../../lyrics/data/repositories/lyrics_repository.dart';
import '../../player/application/providers/audio_provider.dart';
import '../../player/application/services/gapless_prefetch_service.dart';
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

    final clearsLocalAudio = category == 'all' ||
        category == 'group_local' ||
        category == 'local_music';
    final clearsStreamAudio = category == 'all' ||
        category == 'group_stream' ||
        category == 'stream_audio';
    final clearsAnyAudio = clearsLocalAudio || clearsStreamAudio;
    final clearsLyrics = category == 'all' ||
        category == 'group_local' ||
        category == 'local_music' ||
        category == 'local_lyrics' ||
        category == 'group_stream' ||
        category == 'stream_audio' ||
        category == 'stream_lyrics';
    final clearsTranslations = category == 'all' ||
        category == 'group_system' ||
        category == 'translate';
    final clearsAnyImages = category == 'all' ||
        category == 'group_local' ||
        category == 'local_music' ||
        category == 'local_images' ||
        category == 'group_stream' ||
        category == 'stream_audio' ||
        category == 'stream_images' ||
        category == 'group_system' ||
        category == 'images';

    // 1. Stop and reset active playback + abort prefetchers/downloads BEFORE unlinking audio files
    if (clearsAnyAudio) {
      ref.read(gaplessPrefetchServiceProvider).resetLock();
      _mediaCacheService.cancelAllActiveDownloads();
      ref.read(audioProvider.notifier).stopAndClear();
    }

    if (clearsLocalAudio) {
      ref.read(downloadProvider.notifier).cancelAllAndClear();
    }

    // 2. Execute disk deletion concurrently by category
    if (category == 'all') {
      ref.read(playbackArchitectureServiceProvider).clearCache();
      await Future.wait([
        _mediaCacheService.clearCategory('local_music'),
        _mediaCacheService.clearCategory('local_lyrics'),
        _mediaCacheService.clearCategory('local_images'),
        _mediaCacheService.clearCache(),
      ]);
      await ref.read(libraryProvider.notifier).scanLibrary(isBackground: true);
    } else if (category == 'group_local' || category == 'local_music') {
      // Co-delete local lyrics and local thumbnails when local music is cleared, and rescan library
      await Future.wait([
        _mediaCacheService.clearCategory('local_music'),
        _mediaCacheService.clearCategory('local_lyrics'),
        _mediaCacheService.clearCategory('local_images'),
      ]);
      await ref.read(libraryProvider.notifier).scanLibrary(isBackground: true);
    } else if (category == 'group_stream' || category == 'stream_audio') {
      // Co-delete secondary stream images & lyrics when stream audio is cleared
      ref.read(playbackArchitectureServiceProvider).clearCache();
      await Future.wait([
        _mediaCacheService.clearCategory('stream_audio'),
        _mediaCacheService.clearCategory('stream_images'),
        _mediaCacheService.clearCategory('stream_lyrics'),
      ]);
    } else if (category == 'group_system') {
      await Future.wait([
        _mediaCacheService.clearCategory('metadata'),
        _mediaCacheService.clearCategory('translate'),
        _mediaCacheService.clearCategory('images'),
      ]);
    } else {
      await _mediaCacheService.clearCategory(category);
    }

    // 3. Invalidate in-memory lyrics & translation caches
    if (clearsLyrics) {
      ref.read(lyricsRepositoryProvider).clearMemoryCache();
      ref.invalidate(lyricsProvider);
    }
    if (clearsTranslations) {
      ref.invalidate(lyricsTranslationProvider);
    }

    // 4. Sanitize recently played history & invalidate offline/metadata-backed feeds
    if (clearsLocalAudio || clearsAnyImages) {
      await ref
          .read(recentlyPlayedProvider.notifier)
          .sanitizeAfterCacheClear(removeDeletedLocalFiles: clearsLocalAudio);
    }

    if (clearsStreamAudio || category == 'metadata' || category == 'group_system') {
      ref.invalidate(cachedStreamMusicProvider);
      ref.invalidate(playableOfflineTracksProvider);
    }

    final isOnline = ref.read(networkConnectivityProvider).isOnline;
    if (clearsLocalAudio || category == 'metadata' || category == 'group_system' || !isOnline) {
      ref.invalidate(speedDialProvider);
      ref.invalidate(forgottenFavoritesProvider);
    }
    if (!isOnline && (clearsAnyAudio || category == 'metadata' || category == 'group_system')) {
      ref.invalidate(quickPicksProvider);
      ref.invalidate(dailyDiscoverProvider);
    }

    // Use O(1) cached size snapshot (already zeroed for cleared categories) instead of full-disk rescan
    await refresh(force: false);
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
