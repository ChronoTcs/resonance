import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/i_platform_stream_resolver.dart';
import '../../domain/interfaces/i_platform_po_token_service.dart';
import '../../domain/models/stream_resolution_result.dart';
import '../../../../features/explore/data/services/youtube_innertube_client.dart';
import '../../../../features/explore/application/services/youtube_auth_service.dart';

// ── Android-only Stream Resolver ─────────────────────────────────────────────
// Uses InnerTube WEB_REMIX -> WEB profiles with ZemerCipher deobfuscation.
// Disqualifies c=ANDROID streams (YouTube CDN 1MB cap on Android).
// NO Windows / yt-dlp / libmpv imports allowed in this file.
class AndroidStreamResolver implements IPlatformStreamResolver {
  final Ref _ref;
  final IPlatformPoTokenService _poTokenService;
  final http.Client _httpClient;

  AndroidStreamResolver(this._ref, this._poTokenService, this._httpClient);

  @override
  String get platformName => 'android';

  // ── Canonical Android UA Strings (single source of truth) ─────────────────
  static const String _uaWebRemix =
      'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36';

  @override
  String get userAgent => _uaWebRemix;

  @override
  Map<String, String> getPlaybackHeaders(String streamUrl) {
    // Android only plays WEB_REMIX / WEB profile streams.
    // c=ANDROID is disqualified by _isStreamAlive liveness probe.
    final origin = streamUrl.contains('music.youtube.com')
        ? 'https://music.youtube.com'
        : 'https://www.youtube.com';
    return {
      'User-Agent': _uaWebRemix,
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': origin,
      'Referer': '$origin/',
    };
  }

  @override
  Future<StreamResolutionResult> resolveStream(String videoId) async {
    final authService = _ref.read(youtubeAuthServiceProvider);
    final client = _ref.read(youtubeInnerTubeClientProvider);
    final visitorData = await authService.ensureVisitorData();
    final tokenPair = await _poTokenService.getPoToken(visitorData, videoId: videoId);

    // Try WEB_REMIX -> WEB profile chain (c=ANDROID disqualified on Android)
    for (final profile in [YoutubeClientProfile.webRemix, YoutubeClientProfile.web]) {
      final sts = authService.signatureTimestamp;
      try {
        final data = await client.post(
          'player',
          {'videoId': videoId},
          profile: profile,
          useAuth: authService.isLoggedIn,
          signatureTimestamp: sts,
          poToken: tokenPair?.playerPoToken,
        );

        final streamingData = data['streamingData'];
        if (streamingData == null) continue;

        final formats = List<Map<String, dynamic>>.from(
          streamingData['adaptiveFormats'] ?? [],
        );
        if (formats.isEmpty) continue;

        final audioFormat = formats.firstWhere(
          (f) => f['itag'] == 140,
          orElse: () => formats.firstWhere(
            (f) => f['mimeType']?.contains('audio') ?? false,
            orElse: () => formats.first,
          ),
        );

        String? streamUrl;
        if (audioFormat.containsKey('url')) {
          streamUrl = audioFormat['url'] as String;
        } else if (audioFormat.containsKey('signatureCipher')) {
          final cipher = audioFormat['signatureCipher'] as String;
          streamUrl = await _poTokenService.decipherSignature(cipher, videoId);
        }

        if (streamUrl == null) continue;

        // n-param transformation (ZemerCipher)
        final isWebProfile = profile == YoutubeClientProfile.webRemix ||
            profile == YoutubeClientProfile.web;
        if (isWebProfile) {
          final transformed = await _poTokenService.decipherN(streamUrl);
          if (transformed != null) streamUrl = transformed;
        }

        // Append streamPoToken
        if (tokenPair?.streamPoToken != null &&
            tokenPair!.streamPoToken.isNotEmpty &&
            !streamUrl.contains('&pot=')) {
          streamUrl = '$streamUrl&pot=${tokenPair.streamPoToken}';
        }

        // Liveness probe — reject c=ANDROID (1MB cap)
        if (streamUrl.contains('c=ANDROID')) {
          debugPrint('[AndroidStreamResolver] Rejecting c=ANDROID for $videoId (CDN 1MB cap)');
          continue;
        }

        final headers = getPlaybackHeaders(streamUrl);
        final alive = await _isStreamAlive(streamUrl, headers['User-Agent']!);
        if (!alive) {
          debugPrint('[AndroidStreamResolver] Stream dead for ${profile.name} $videoId, rotating...');
          continue;
        }

        debugPrint('[AndroidStreamResolver] Resolved $videoId via ${profile.name}');
        return StreamResolutionResult(
          streamUrl: streamUrl,
          playbackHeaders: headers,
          expiresAt: _parseExpiry(streamUrl),
        );
      } catch (e) {
        debugPrint('[AndroidStreamResolver] ${profile.name} failed for $videoId: $e');
      }
    }

    throw Exception('[AndroidStreamResolver] All profiles failed for $videoId');
  }

  Future<bool> _isStreamAlive(String url, String userAgent) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = userAgent;
      request.headers['Range'] = 'bytes=0-1024';
      request.headers['Accept'] = '*/*';
      final response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  DateTime _parseExpiry(String streamUrl) {
    try {
      final uri = Uri.parse(streamUrl);
      final expireStr = uri.queryParameters['expire'];
      if (expireStr != null) {
        final epoch = int.tryParse(expireStr);
        if (epoch != null) {
          return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
        }
      }
    } catch (_) {}
    return DateTime.now().add(const Duration(hours: 6));
  }
}
