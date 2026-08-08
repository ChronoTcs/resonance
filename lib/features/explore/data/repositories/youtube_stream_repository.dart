import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../../core/data/services/storage_service.dart';
import '../services/youtube_innertube_client.dart';
import '../services/youtube_po_token_service.dart';
import '../../application/services/youtube_auth_service.dart';
import '../../../download/application/download_service.dart';

final youtubeStreamRepositoryProvider = Provider<YoutubeStreamRepository>((ref) {
  final client = ref.watch(youtubeInnerTubeClientProvider);
  final cacheService = ref.watch(mediaCacheServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  
  final repo = YoutubeStreamRepository(ref, client, cacheService, prefs);
  ref.onDispose(() => repo.dispose());
  // warm-up only needed on Android (no native cookie sync like Windows)
  if (Platform.isAndroid) repo.warmUpSession();
  return repo;
});

enum YoutubeEngine { explodeDart, innerTube }

class YoutubeStreamRepository {
  final Ref _ref;
  final YoutubeInnerTubeClient _client;
  final MediaCacheService _cacheService;
  final SharedPreferences _prefs;
  final yt.YoutubeExplode _explode = yt.YoutubeExplode();

  YoutubeStreamRepository(this._ref, this._client, this._cacheService, this._prefs);

  /// Resolves the final playable audio URL with Cache-First strategy
  Future<String?> getStreamUrl(String videoId) async {
    // [GUARDRAIL 2] MANDATORY CACHE-FIRST
    try {
      final cachedPath = await _cacheService.getCachedAudioPath(videoId);
      if (cachedPath != null) {
        debugPrint('YoutubeStreamRepository: [CACHE HIT] Using local file for $videoId');
        return cachedPath;
      }
    } catch (e) {
      debugPrint('YoutubeStreamRepository: Cache check error: $e');
    }

    if (Platform.isWindows) {
      debugPrint('YoutubeStreamRepository: Resolving stream via Windows Python IPC...');
      final resolvedUrl = await _ref.read(downloadServiceProvider).resolveStreamUrl(videoId);
      if (resolvedUrl != null) {
        debugPrint('YoutubeStreamRepository: Stream resolved successfully via Windows IPC.');
        // yt-dlp uses ANDROID_VR client — URL is UA-locked, must match
        const userAgent = 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
        return await _cacheService.getAudioPath(videoId, resolvedUrl, userAgent: userAgent);
      }
      debugPrint('YoutubeStreamRepository: Windows IPC resolution failed. Escalating to Explode Fail-Safe.');
    } else {
      // Instantly generate token based on fresh visitorData. No WebView wait!
      final visitorData = _ref.read(youtubeAuthServiceProvider).visitorData;
      String? poToken;
      if (visitorData != null && visitorData.isNotEmpty) {
        poToken = await _ref.read(youtubePoTokenServiceProvider).generatePoToken(visitorData);
      }

      final engine = _getEngineSetting();
      if (engine == YoutubeEngine.innerTube) {
        final result = await _getInnerTubeAudioWithProfile(videoId, poToken: poToken);
        if (result != null && result.streamUrl != null) {
          final userAgent = _client.getUserAgent(result.profile);
          debugPrint('YoutubeStreamRepository: Using UA from ${result.profile.name} for download...');
          // Memeriksa nyawa URL sebelum percaya buta
          debugPrint('YoutubeStreamRepository: Probing stream health...');
          final isAlive = await _isStreamAlive(result.streamUrl!, userAgent);
          
          if (isAlive) {
            try {
              return await _cacheService.getAudioPath(videoId, result.streamUrl!, userAgent: userAgent);
            } catch (e) {
              debugPrint('YoutubeStreamRepository: Cacher failed. URL might be throttled or forbidden: $e');
              debugPrint('YoutubeStreamRepository: Escalating to Fail-Safe...');
            }
          } else {
            debugPrint('YoutubeStreamRepository: [PROBER] Detected dead stream (403) from ${result.profile.name}. Rejecting InnerTube...');
          }
        }
        debugPrint('YoutubeStreamRepository: InnerTube Pipeline rejected or failed. Escalating to Explode Fail-Safe for $videoId...');
      }
    }
    
    // Final Fallback (Explode Dart)
    final explodeUrl = await _searchExplodeStream(videoId);
    if (explodeUrl != null) {
      // Since explode uses ytClients [androidVr, ios].
      final explodeUa = 'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)';
      return await _cacheService.getAudioPath(videoId, explodeUrl, userAgent: explodeUa);
    }
    return null;
  }

  Future<bool> _isStreamAlive(String url, String userAgent) async {
    try {
      // Use HEAD request without Range constraints to verify authentic HTTP 403 status
      final request = http.Request('HEAD', Uri.parse(url));
      request.headers['User-Agent'] = userAgent;
      final response = await http.Client().send(request).timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _searchExplodeStream(String videoId) async {
    debugPrint('YoutubeStreamRepository: Fetching stream via youtube_explode for ID: $videoId...');
    try {
      final manifest = await _explode.videos.streamsClient.getManifest(
        videoId,
        ytClients: [yt.YoutubeApiClient.androidVr, yt.YoutubeApiClient.ios],
      );
      final audioStreams = manifest.audioOnly;
      
      final mp4Streams = audioStreams.where((e) => e.container.name.toLowerCase() == 'mp4' || e.container.name.toLowerCase() == 'm4a');
      
      final audioInfo = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : audioStreams.withHighestBitrate();
          
      return audioInfo.url.toString();
    } catch (e) {
      debugPrint('YoutubeStreamRepository: [ERROR] Explode extraction failed: $e');
      final visitorData = _ref.read(youtubeAuthServiceProvider).visitorData;
      String? poToken;
      if (visitorData != null && visitorData.isNotEmpty) {
        poToken = await _ref.read(youtubePoTokenServiceProvider).generatePoToken(visitorData);
      }
      final res = await _getInnerTubeAudioWithProfile(videoId, poToken: poToken);
      return res?.streamUrl;
    }
  }

  Future<({String? streamUrl, YoutubeClientProfile profile})?> _getInnerTubeAudioWithProfile(String videoId, {String? poToken}) async {
    // Step 1: Attempt 1 (WEB_REMIX)
    final firstResult = await _fetchFromInnerTube(
      videoId, 
      YoutubeClientProfile.webRemix, 
      useAuth: true, 
      sts: null,
      poToken: poToken,
    );
    
    if (firstResult != null && firstResult.streamUrl != null) {
      return (streamUrl: firstResult.streamUrl, profile: YoutubeClientProfile.webRemix);
    }

    // Client uses main www.youtube.com domain and utilizes poToken for all streams
    debugPrint('YoutubeStreamRepository: Rotating to WEB...');
    final webResult = await _fetchFromInnerTube(
      videoId,
      YoutubeClientProfile.web,
      useAuth: true,
      sts: null,
      poToken: poToken,
    );

    if (webResult != null && webResult.streamUrl != null) {
      return (streamUrl: webResult.streamUrl, profile: YoutubeClientProfile.web);
    }

    // Step 3: Attempt 3 (ANDROID_MUSIC)
    debugPrint('YoutubeStreamRepository: Rotating to ANDROID_MUSIC...');
    final musicResult = await _fetchFromInnerTube(
      videoId, 
      YoutubeClientProfile.androidMusic, 
      useAuth: false, 
      sts: null,
      poToken: null,
    );

    if (musicResult != null && musicResult.streamUrl != null) {
      return (streamUrl: musicResult.streamUrl, profile: YoutubeClientProfile.androidMusic);
    }

    // Step 4: Attempt 4 (ANDROID)
    debugPrint('YoutubeStreamRepository: Rotating to ANDROID (Main App)...');
    final mainAppResult = await _fetchFromInnerTube(
      videoId, 
      YoutubeClientProfile.android, 
      useAuth: false, 
      sts: null,
      poToken: null,
    );

    if (mainAppResult != null && mainAppResult.streamUrl != null) {
      return (streamUrl: mainAppResult.streamUrl, profile: YoutubeClientProfile.android);
    }

    return null;
  }

  Future<({String? streamUrl, String? baseJsUrl})?> _fetchFromInnerTube(
    String videoId, 
    YoutubeClientProfile profile, {
    required bool useAuth, 
    int? sts,
    String? poToken,
  }) async {
    try {
      final data = await _client.post('player', <String, dynamic>{
        "videoId": videoId,
        "playbackContext": <String, dynamic>{
          "contentCheckOk": true,
          "racyCheckOk": true,
        }
      }, 
      profile: profile, 
      useAuth: useAuth,
      signatureTimestamp: sts,
      poToken: poToken,
      );

      final String? jsPath = data['assets']?['js'];
      final String? baseJsUrl = jsPath != null ? 'https://www.youtube.com$jsPath' : null;
      
      // Capture real visitorData from every response so next songs always have a valid token
      final String? responseVisitorData = data['responseContext']?['visitorData'] as String?;
      if (responseVisitorData != null && responseVisitorData.isNotEmpty) {
        unawaited(_ref.read(youtubeAuthServiceProvider).cacheVisitorData(responseVisitorData));
      }
      
      final streamingData = data['streamingData'];
      if (streamingData == null) {
        debugPrint('YoutubeStreamRepository: No streaming data for ${profile.name}');
        return (streamUrl: null, baseJsUrl: baseJsUrl);
      }

      final formats = List<Map<String, dynamic>>.from(streamingData['adaptiveFormats'] ?? []);
      if (formats.isEmpty) return (streamUrl: null, baseJsUrl: baseJsUrl);

      // Filter for audio itag 140 (M4A 128kbps) or best audio
      final audioFormat = formats.firstWhere(
        (f) => f['itag'] == 140,
        orElse: () => formats.firstWhere((f) => f['mimeType']?.contains('audio') ?? false, orElse: () => formats.first),
      );

      String? streamUrl;
      if (audioFormat.containsKey('url')) {
        streamUrl = audioFormat['url'] as String;
      } else if (audioFormat.containsKey('signatureCipher')) {
        final cipher = audioFormat['signatureCipher'] as String;
        final cipherMap = Uri.splitQueryString(cipher);
        final baseUrl = cipherMap['url'];
        final s = cipherMap['s'];
        final sp = cipherMap['sp'] ?? 'sig'; // Default to 'sig' if sp is missing

        if (Platform.isAndroid) {
          debugPrint('YoutubeStreamRepository: Deciphering signatureCipher via Android zemer-cipher...');
          final decipheredUrl = await _ref.read(youtubePoTokenServiceProvider).decipherSignature(cipher, videoId);
          if (decipheredUrl != null) {
            streamUrl = decipheredUrl;
          }
        } else {
          if (baseUrl != null && s != null) {
            // Deciphering fallback path (not reachable in typical Android/Windows scenarios)
            final baseUri = Uri.parse(baseUrl);
            final updatedParams = Map<String, String>.from(baseUri.queryParameters);
            updatedParams[sp] = s;
            streamUrl = baseUri.replace(queryParameters: updatedParams).toString();
          }
        }
      }

      if (streamUrl == null) return (streamUrl: null, baseJsUrl: baseJsUrl);
      
      if (Platform.isAndroid) {
        debugPrint('YoutubeStreamRepository: Transforming n-parameter via Android zemer-cipher...');
        final transformedUrl = await _ref.read(youtubePoTokenServiceProvider).decipherN(streamUrl);
        if (transformedUrl != null) {
          streamUrl = transformedUrl;
        }
      }

      return (streamUrl: streamUrl, baseJsUrl: baseJsUrl);
    } catch (e) {
      debugPrint('YoutubeStreamRepository: Error fetching via ${profile.name}: $e');
      return null;
    }
  }

  YoutubeEngine _getEngineSetting() {
    final val = _prefs.getString('yt_engine') ?? 'innertube';
    return val == 'explode' ? YoutubeEngine.explodeDart : YoutubeEngine.innerTube;
  }

  /// [Android Cold-Start Warm-Up] Fires a cheap InnerTube browse call in the background
  /// so responseContext.visitorData is cached before the user plays the first song.
  Future<void> warmUpSession() async {
    // Skip if visitorData already cached from a previous session
    if (_ref.read(youtubeAuthServiceProvider).visitorData != null) return;
    try {
      debugPrint('YoutubeStreamRepository: [WARM-UP] Fetching real visitorData from YouTube...');
      final data = await _client.post('browse', <String, dynamic>{
        'browseId': 'FEmusic_home',
      }, profile: YoutubeClientProfile.webRemix, useAuth: false);
      final String? vd = data['responseContext']?['visitorData'] as String?;
      if (vd != null && vd.isNotEmpty) {
        await _ref.read(youtubeAuthServiceProvider).cacheVisitorData(vd);
        debugPrint('YoutubeStreamRepository: [WARM-UP] visitorData cached: ${vd.substring(0, 10)}...');
      }
    } catch (e) {
      debugPrint('YoutubeStreamRepository: [WARM-UP] Failed (non-critical): $e');
    }
  }

  void dispose() {
    _explode.close();
  }
}
