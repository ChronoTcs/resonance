import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/interfaces/i_platform_stream_resolver.dart';
import '../../domain/models/stream_resolution_result.dart';
import '../../../../features/download/application/download_service.dart';

// ── Linux-only Stream Resolver ─────────────────────────────────────────────
// Uses yt-dlp via Python IPC (DownloadService.resolveStreamUrl).
// Owns canonical Linux User-Agent strings for all client types.
// NO Android / libmpv imports allowed in this file.
class LinuxStreamResolver implements IPlatformStreamResolver {
  final Ref _ref;

  LinuxStreamResolver(this._ref);

  @override
  String get platformName => 'linux';

  // ── Canonical Linux UA Strings (single source of truth) ─────────────────
  // Matches signatures embedded in yt-dlp CDN URLs.
  static const String _uaAndroid1929 =
      'com.google.android.youtube/19.29.37 (Linux; U; Android 14; GB) gzip';
  static const String _uaAndroidVr =
      'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1)';
  static const String _uaIos =
      'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)';
  static const String _uaWeb =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  @override
  String get userAgent => _uaAndroid1929;

  /// Returns the correct UA for a specific [streamUrl] based on client type query param.
  String _uaForUrl(String streamUrl) {
    if (streamUrl.contains('c=ANDROID_VR')) return _uaAndroidVr;
    if (streamUrl.contains('c=ANDROID')) return _uaAndroid1929;
    if (streamUrl.contains('c=IOS')) return _uaIos;
    return _uaWeb;
  }

  @override
  Map<String, String> getPlaybackHeaders(String streamUrl) {
    final ua = _uaForUrl(streamUrl);
    final isWeb = !streamUrl.contains('c=ANDROID') &&
        !streamUrl.contains('c=ANDROID_VR') &&
        !streamUrl.contains('c=IOS');
    final origin = streamUrl.contains('music.youtube.com')
        ? 'https://music.youtube.com'
        : 'https://www.youtube.com';

    return {
      'User-Agent': ua,
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Connection': 'keep-alive',
      if (isWeb) ...{
        'Origin': origin,
        'Referer': '$origin/',
        'Sec-Fetch-Dest': 'audio',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
      },
    };
  }

  @override
  Future<StreamResolutionResult> resolveStream(String videoId) async {
    final downloadService = _ref.read(downloadServiceProvider);
    final resolvedUrl = await downloadService.resolveStreamUrl(videoId);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      throw Exception('[LinuxStreamResolver] yt-dlp IPC returned null for $videoId');
    }

    debugPrint('[LinuxStreamResolver] Resolved $videoId via yt-dlp IPC');

    // CDN URLs expire in ~6h; use conservative 5h window
    final expiresAt = DateTime.now().add(const Duration(hours: 5));

    return StreamResolutionResult(
      streamUrl: resolvedUrl,
      playbackHeaders: getPlaybackHeaders(resolvedUrl),
      expiresAt: expiresAt,
    );
  }
}
