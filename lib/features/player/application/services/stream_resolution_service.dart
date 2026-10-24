import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import '../../../../core/data/services/media_cache_service.dart';
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/exceptions/offline_exception.dart';
import '../../../library/data/models/media_item.dart';
import '../../../stream/domain/interfaces/i_platform_stream_resolver.dart';
import '../../../stream/application/platform_stream_provider.dart';
import 'playback_architecture_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

/// Resolves the final playable URL/path for a streaming [MediaItem].
///
/// Responsibility chain:
/// 1. Is the item actually a physical local file? → return path directly.
/// 2. Is there a persistent audio cache? → return cached path.
/// 3. Fetch via PlaybackArchitectureService (YouTubeExplode + in-memory cache).
///
/// Returns the resolved path/URL, or throws if resolution fails.
/// The AudioNotifier simply calls [resolve] and feeds the result to media_kit.
class StreamResolutionService {
  final Ref _ref;
  final IPlatformStreamResolver _resolver;

  StreamResolutionService(this._ref, this._resolver);

  /// Resolves the full playable path for [item].
  ///
  /// For local files: returns the path unchanged.
  /// For streaming items: resolves via cache → architecture service chain.
  ///
  /// Triggers background tasks (persistent cache, metadata save) as side effects.
  Future<String> resolve(MediaItem item) async {
    final songId = (item.id != null && item.id!.isNotEmpty && !item.id!.startsWith('http'))
        ? item.id!
        : (item.path.startsWith('http') ? (item.id ?? item.path) : item.path);

    // ── 1. Physical local file check ───────────────────────────────────────
    final hasSlash = item.path.contains('/') || item.path.contains('\\');
    final isStreamCache = item.path.replaceAll('\\', '/').contains('/stream/') ||
        item.path.replaceAll('\\', '/').contains('/cache/');
    if (!item.isStreaming && hasSlash && !isStreamCache) {
      debugPrint('[StreamResolution] Local file: ${item.path}');
      return item.path;
    }

    // ── 2. Persistent audio cache hit ─────────────────────────────────────
    final cacheService = _ref.read(mediaCacheServiceProvider);
    final cachedPath = await cacheService.getCachedAudioPath(songId);
    if (cachedPath != null) {
      debugPrint('[StreamResolution] Cache hit for $songId');
      return cachedPath;
    }

    // ── 3. Architecture service (stream URL) ───────────────────────────────
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      throw const OfflinePlaybackException(
        'Device is offline and no cached audio is available.',
      );
    }

    final archService = _ref.read(playbackArchitectureServiceProvider);
    final String? streamUrl;
    try {
      streamUrl = await archService.getStreamUrl(songId);
    } on OfflinePlaybackException {
      rethrow;
    }
    if (streamUrl == null) {
      throw Exception('[StreamResolution] Failed to resolve stream for $songId');
    }

    debugPrint('[StreamResolution] Stream URL resolved for $songId');

    // NOTE: Background caching is now triggered from AudioNotifier on track completion
    // (after FFmpeg closes its socket) to avoid concurrent socket collision on the same CDN URL.
    Future.microtask(() => cacheService.saveMetadata(songId, item));

    return streamUrl;
  }

  /// Returns platform-specific playback headers for a given stream URL.
  /// Used by the completion caching logic in AudioNotifier.
  Map<String, String> getHeaders(String streamUrl) {
    return _resolver.getPlaybackHeaders(streamUrl);
  }

  /// Force-resolves a fresh stream URL, bypassing all caches.
  /// Used for 1-shot retry after a resolution failure in playTrack.
  Future<String> resolveForced(MediaItem item) async {
    final songId = (item.id != null && item.id!.isNotEmpty && !item.id!.startsWith('http'))
        ? item.id!
        : (item.path.startsWith('http') ? (item.id ?? item.path) : item.path);

    if (!_ref.read(networkConnectivityProvider).isOnline) {
      throw const OfflinePlaybackException(
        'Device is offline and no cached audio is available.',
      );
    }

    final archService = _ref.read(playbackArchitectureServiceProvider);
    final String? streamUrl;
    try {
      streamUrl = await archService.getStreamUrl(songId, forceRefresh: true);
    } on OfflinePlaybackException {
      rethrow;
    }
    if (streamUrl == null) {
      throw Exception('[StreamResolution] Force-resolve failed for $songId');
    }
    debugPrint('[StreamResolution] Force-resolved $songId');
    return streamUrl;
  }

  Media buildMedia(String resolvedPath, {dynamic player}) {
    if (resolvedPath.startsWith('http')) {
      final headers = _resolver.getPlaybackHeaders(resolvedPath);
      if (player != null && Platform.isWindows) {
        try {
          (player.platform as dynamic).setProperty(
            'user-agent',
            headers['User-Agent'] ?? _resolver.userAgent,
          );
        } catch (_) {}
      }
      return Media(resolvedPath, httpHeaders: headers);
    }
    return Media(resolvedPath);
  }
}

// ── MPV Configurator (static utility) ─────────────────────────────────────────

/// Infrastructure configurator for MPV-specific settings.
class MpvConfigurator {
  /// Builds the MPV audio filter string from active equalizer settings.
  /// If [eqFilter] is null or empty, returns an empty string to cleanly bypass all filters.
  static String buildAudioFilter([String? eqFilter]) {
    if (eqFilter != null && eqFilter.isNotEmpty) {
      return eqFilter;
    }
    return '';
  }

  /// Redirects the MPV buffer/cache to [customPath] and applies unified EBU R128 loudness normalization and EQ.
  static void applyCacheSettings(dynamic player, String? customPath, {String? eqFilter}) {
    Future.microtask(() async {
      try {
        // Startup MPV Demuxer Memory Caps (platform-tuned: 32MiB/16MiB on Android, 100MiB/50MiB on Desktop)
        final maxBytes = Platform.isAndroid ? '32MiB' : '100MiB';
        final maxBackBytes = Platform.isAndroid ? '16MiB' : '50MiB';
        await (player.platform as dynamic).setProperty('demuxer-max-bytes', maxBytes);
        await (player.platform as dynamic).setProperty('demuxer-max-back-bytes', maxBackBytes);
        await (player.platform as dynamic).setProperty(
          'demuxer-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_on_http_error=4xx,5xx,reconnect_delay_max=5',
        );
        await (player.platform as dynamic).setProperty('network-timeout', '15');
        await (player.platform as dynamic).setProperty('vo', 'null');
        await (player.platform as dynamic).setProperty('vid', 'no');

        if (customPath != null && customPath.isNotEmpty) {
          final mpvTemp = Directory(p.join(customPath, 'mpv_temp'));
          if (!mpvTemp.existsSync()) {
            mpvTemp.createSync(recursive: true);
          }
          await (player.platform as dynamic).setProperty('cache', 'yes');
          await (player.platform as dynamic).setProperty('cache-dir', mpvTemp.path);
          debugPrint('[MpvConfigurator] Cache redirected to: ${mpvTemp.path}');
        }

        // Unified Audio Filter Graph: EBU R128 Loudness Normalization + active EQ
        // Only apply on Desktop or when non-empty to prevent Android audiotrack filter init errors.
        final fullFilter = buildAudioFilter(eqFilter);
        if (!Platform.isAndroid || fullFilter.isNotEmpty) {
          await (player.platform as dynamic).setProperty('af', fullFilter);
          debugPrint('[MpvConfigurator] Audio filter graph applied: $fullFilter');
        }
      } catch (e) {
        debugPrint('[MpvConfigurator] Failed to set properties: $e');
      }
    });
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final streamResolutionServiceProvider = Provider<StreamResolutionService>((ref) {
  final resolver = ref.watch(platformStreamResolverProvider);
  return StreamResolutionService(ref, resolver);
});
