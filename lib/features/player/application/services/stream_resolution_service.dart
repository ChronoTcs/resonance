import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import '../../../../core/data/services/media_cache_service.dart';
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
    final archService = _ref.read(playbackArchitectureServiceProvider);
    final streamUrl = await archService.getStreamUrl(songId);
    if (streamUrl == null) {
      throw Exception('[StreamResolution] Failed to resolve stream for $songId');
    }

    debugPrint('[StreamResolution] Stream URL resolved for $songId');

    // Defer disk caching by 10s — gives player 100% bandwidth to fill demuxer buffer
    if (streamUrl.startsWith('http') && !streamUrl.contains('c=ANDROID_VR')) {
      Future.delayed(const Duration(seconds: 10), () {
        final headers = _resolver.getPlaybackHeaders(streamUrl);
        cacheService.getAudioPath(songId, streamUrl, headers: headers);
      });
    }
    Future.microtask(() => cacheService.saveMetadata(songId, item));

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
/// All operations are fire-and-forget (via [Future.microtask]).
class MpvConfigurator {
  /// Redirects the MPV buffer/cache to [customPath] and applies EBU R128 loudness normalization.
  static void applyCacheSettings(dynamic player, String? customPath) {
    Future.microtask(() async {
      try {
        if (customPath != null && customPath.isNotEmpty) {
          final mpvTemp = Directory(p.join(customPath, 'mpv_temp'));
          if (!mpvTemp.existsSync()) {
            mpvTemp.createSync(recursive: true);
          }
          await (player.platform as dynamic).setProperty('cache', 'yes');
          await (player.platform as dynamic).setProperty('cache-dir', mpvTemp.path);
          await (player.platform as dynamic).setProperty('demuxer-max-bytes', '100MiB');
          await (player.platform as dynamic).setProperty('demuxer-max-back-bytes', '50MiB');
          await (player.platform as dynamic).setProperty('demuxer-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
          await (player.platform as dynamic).setProperty('network-timeout', '10');
          await (player.platform as dynamic).setProperty('tls-verify', 'no');
          debugPrint('[MpvConfigurator] Cache redirected to: ${mpvTemp.path}');
        }

        // EBU R128 Loudness Normalization via FFmpeg libavfilter
        await (player.platform as dynamic).setProperty('af', 'lavfi=[loudnorm=I=-14:TP=-1.5:LRA=11]');
        debugPrint('[MpvConfigurator] Loudness normalization applied (lavfi loudnorm I=-14, TP=-1.5)');
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
