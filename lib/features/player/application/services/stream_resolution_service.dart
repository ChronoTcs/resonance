import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import '../../../../core/data/services/media_cache_service.dart';
import '../../../library/data/models/media_item.dart';
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

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  StreamResolutionService(this._ref);

  /// Resolves the full playable path for [item].
  ///
  /// For local files: returns the path unchanged.
  /// For streaming items: resolves via cache → architecture service chain.
  ///
  /// Triggers background tasks (persistent cache, metadata save) as side effects.
  Future<String> resolve(MediaItem item) async {
    final songId = item.id ?? item.path;

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

    // Trigger background caching as side effects for non-session-locked HTTP streams (non-blocking)
    if (streamUrl.startsWith('http') && !streamUrl.contains('c=ANDROID_VR')) {
      Future.microtask(() => cacheService.getAudioPath(songId, streamUrl));
    }
    Future.microtask(() => cacheService.saveMetadata(songId, item));

    return streamUrl;
  }

  String getUserAgent(String resolvedPath) {
    if (!resolvedPath.startsWith('http')) return _defaultUserAgent;
    if (resolvedPath.contains('c=ANDROID_VR')) {
      return 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1)';
    }
    if (resolvedPath.contains('c=ANDROID')) {
      return 'com.google.android.youtube/19.29.37 (Linux; U; Android 14; GB) gzip';
    }
    if (resolvedPath.contains('c=IOS')) {
      return 'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)';
    }
    return _defaultUserAgent;
  }

  Media buildMedia(String resolvedPath, {dynamic player}) {
    if (resolvedPath.startsWith('http')) {
      final userAgent = getUserAgent(resolvedPath);
      if (player != null && Platform.isWindows) {
        try {
          (player.platform as dynamic).setProperty('user-agent', userAgent);
        } catch (_) {}
      }
      return Media(resolvedPath, httpHeaders: {
        'User-Agent': userAgent,
      });
    }
    return Media(resolvedPath);
  }
}

// ── MPV Configurator (static utility) ─────────────────────────────────────────

/// Infrastructure configurator for MPV-specific settings.
/// All operations are fire-and-forget (via [Future.microtask]).
class MpvConfigurator {
  /// Redirects the MPV buffer/cache to [customPath] for stable network streaming.
  static void applyCacheSettings(dynamic player, String? customPath) {
    if (customPath == null || customPath.isEmpty) return;

    Future.microtask(() async {
      try {
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
      } catch (e) {
        debugPrint('[MpvConfigurator] Failed to set properties: $e');
      }
    });
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final streamResolutionServiceProvider = Provider<StreamResolutionService>((ref) {
  return StreamResolutionService(ref);
});
