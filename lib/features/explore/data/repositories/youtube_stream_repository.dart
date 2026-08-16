import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/exceptions/offline_exception.dart';
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
        debugPrint('[YoutubeStreamRepo][CACHE HIT] Using local file for $videoId');
        return cachedPath;
      }
    } catch (e) {
      debugPrint('[YoutubeStreamRepo] Cache check error: $e');
    }

    // [OFFLINE GUARD] No cache hit — abort immediately if device is offline
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      debugPrint('[YoutubeStreamRepo] Offline — skipping stream resolution for $videoId');
      throw const OfflinePlaybackException();
    }

    final streamSource = _prefs.getString('stream_source') ?? 'ipc';
    final isIpcFirst = streamSource == 'ipc';

    debugPrint(
      '[YoutubeStreamRepo] Resolving $videoId | Active Strategy: ${isIpcFirst ? "Native IPC First (yt-dlp) -> Dart Fallback" : "In-App Dart First (youtube_explode) -> IPC Fallback"} (setting=$streamSource)',
    );

    if (isIpcFirst && Platform.isWindows) {
      // ── Strategy 1 (Default): Windows IPC First -> Fallback to Dart In-App ──
      final ipcResult = await _tryResolveIpc(videoId);
      if (ipcResult != null) return ipcResult;

      debugPrint('[YoutubeStreamRepo] Windows IPC failed/rejected. Escalating to In-App Dart Fail-Safe.');
      return await _tryResolveDart(videoId);
    } else {
      // ── Strategy 2 (Opposite): In-App Dart First -> Fallback to Windows IPC ──
      debugPrint('[YoutubeStreamRepo] Resolving via In-App Dart first (streamSource=$streamSource)...');
      final dartResult = await _tryResolveDart(videoId);
      if (dartResult != null) return dartResult;

      if (Platform.isWindows) {
        debugPrint('[YoutubeStreamRepo] In-App Dart failed. Escalating to Windows IPC Fail-Safe.');
        return await _tryResolveIpc(videoId);
      }
      return null;
    }
  }

  Future<String?> _tryResolveIpc(String videoId) async {
    if (!Platform.isWindows) return null;
    try {
      debugPrint('[YoutubeStreamRepo] Resolving stream via Windows Python IPC...');
      final resolvedUrl = await _ref.read(downloadServiceProvider).resolveStreamUrl(videoId);
      if (resolvedUrl != null) {
        // Probe health with exact matching User-Agent to prevent signature rejection
        final userAgent = resolvedUrl.contains('c=ANDROID_VR')
            ? 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1)'
            : resolvedUrl.contains('c=ANDROID')
                ? 'com.google.android.youtube/19.29.37 (Linux; U; Android 14; GB) gzip'
                : resolvedUrl.contains('c=IOS')
                    ? 'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)'
                    : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
        final isAlive = await _isStreamAlive(resolvedUrl, userAgent);
        if (isAlive) {
          debugPrint('[YoutubeStreamRepo] Stream resolved and verified alive via Windows IPC.');
          return resolvedUrl;
        } else {
          debugPrint('[YoutubeStreamRepo][PROBER] Windows IPC returned dead/403 stream. Auto-escalating to Dart Fail-Safe...');
        }
      }
    } catch (e) {
      debugPrint('[YoutubeStreamRepo] Windows IPC error: $e');
    }
    return null;
  }

  Future<String?> _tryResolveDart(String videoId) async {
    // 1. Instantly resolve token based on fresh visitorData / PoTokenProviderService
    final visitorData = _ref.read(youtubeAuthServiceProvider).visitorData;
    String? poToken;
    if (visitorData != null && visitorData.isNotEmpty) {
      poToken = await _ref.read(youtubePoTokenServiceProvider).generatePoToken(visitorData);
    } else {
      poToken = await _ref.read(youtubePoTokenServiceProvider).generatePoToken('');
    }

    // 2. Primary Fast In-App Engine: Explode Dart (with PoToken + androidVr)
    final explodeUrl = await _searchExplodeStream(videoId, poToken: poToken);
    if (explodeUrl != null) {
      final explodeUa = explodeUrl.contains('c=ANDROID_VR')
          ? 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1)'
          : explodeUrl.contains('c=IOS')
              ? 'com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)'
              : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      final isAlive = await _isStreamAlive(explodeUrl, explodeUa);
      if (isAlive) {
        return await _cacheService.getAudioPath(videoId, explodeUrl, userAgent: explodeUa);
      } else {
        debugPrint('[YoutubeStreamRepo][PROBER] Explode URL returned dead/403. Falling back to InnerTube...');
      }
    }

    // 3. Fail-Safe: InnerTube (only if Explode ever fails)
    debugPrint('[YoutubeStreamRepo] Explode failed for $videoId. Escalating to InnerTube Fallback...');
    final result = await _getInnerTubeAudioWithProfile(videoId, poToken: poToken);
    if (result != null && result.streamUrl != null) {
      final userAgent = _client.getUserAgent(result.profile);
      final isAlive = await _isStreamAlive(result.streamUrl!, userAgent);
      if (isAlive) {
        try {
          return await _cacheService.getAudioPath(videoId, result.streamUrl!, userAgent: userAgent);
        } catch (e) {
          debugPrint('[YoutubeStreamRepo] Cacher failed: $e');
        }
      }
    }

    return null;
  }

  yt.YoutubeApiClient _buildPoTokenClient(String poToken) {
    return yt.YoutubeApiClient(
      {
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20250312.04.00',
            'userAgent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'hl': 'en',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
          },
        },
        'serviceIntegrityDimensions': {
          'poToken': poToken,
        },
      },
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    );
  }

  Future<bool> _isStreamAlive(String url, String userAgent) async {
    try {
      // Use lightweight GET Range request — YouTube CDN rejects HEAD requests with 403
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = userAgent;
      request.headers['Range'] = 'bytes=0-1024';
      request.headers['Accept'] = '*/*';
      final response = await http.Client().send(request).timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _searchExplodeStream(String videoId, {String? poToken}) async {
    debugPrint('[YoutubeStreamRepo] Fetching stream via youtube_explode for ID: $videoId...');
    try {
      final List<yt.YoutubeApiClient> clients = [];
      if (poToken != null && poToken.isNotEmpty) {
        clients.add(_buildPoTokenClient(poToken));
      }
      clients.addAll([yt.YoutubeApiClient.androidVr, yt.YoutubeApiClient.ios]);

      final manifest = await _explode.videos.streamsClient.getManifest(
        videoId,
        ytClients: clients,
      );
      final audioStreams = manifest.audioOnly;
      
      final mp4Streams = audioStreams.where((e) => 
        e.container.name.toLowerCase() == 'mp4' || 
        e.container.name.toLowerCase() == 'm4a' ||
        e.codec.mimeType.toLowerCase().contains('mp4') ||
        e.codec.mimeType.toLowerCase().contains('aac') ||
        e.tag == 140
      );
      
      final audioInfo = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : null;
      if (audioInfo == null) {
        throw Exception('No playable MP4/AAC stream found in Explode for $videoId');
      }
          
      return audioInfo.url.toString();
    } catch (e) {
      debugPrint('[YoutubeStreamRepo][ERROR] Explode extraction failed: $e');
      final visitorData = _ref.read(youtubeAuthServiceProvider).visitorData;
      String? fallbackPoToken = poToken;
      if (fallbackPoToken == null && visitorData != null && visitorData.isNotEmpty) {
        fallbackPoToken = await _ref.read(youtubePoTokenServiceProvider).generatePoToken(visitorData);
      }
      final res = await _getInnerTubeAudioWithProfile(videoId, poToken: fallbackPoToken);
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
    debugPrint('[YoutubeStreamRepo] Rotating to WEB...');
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
    debugPrint('[YoutubeStreamRepo] Rotating to ANDROID_MUSIC...');
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
    debugPrint('[YoutubeStreamRepo] Rotating to ANDROID (Main App)...');
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
        debugPrint('[YoutubeStreamRepo] No streaming data for ${profile.name}');
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
          debugPrint('[YoutubeStreamRepo] Deciphering signatureCipher via Android zemer-cipher...');
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
        debugPrint('[YoutubeStreamRepo] Transforming n-parameter via Android zemer-cipher...');
        final transformedUrl = await _ref.read(youtubePoTokenServiceProvider).decipherN(streamUrl);
        if (transformedUrl != null) {
          streamUrl = transformedUrl;
        }
      }

      return (streamUrl: streamUrl, baseJsUrl: baseJsUrl);
    } catch (e) {
      debugPrint('[YoutubeStreamRepo] Error fetching via ${profile.name}: $e');
      return null;
    }
  }



  /// [Android Cold-Start Warm-Up] Fires a cheap InnerTube browse call in the background
  /// so responseContext.visitorData is cached before the user plays the first song.
  Future<void> warmUpSession() async {
    // Skip if visitorData already cached from a previous session
    if (_ref.read(youtubeAuthServiceProvider).visitorData != null) return;
    try {
      debugPrint('[YoutubeStreamRepo][WARM-UP] Fetching real visitorData from YouTube...');
      final data = await _client.post('browse', <String, dynamic>{
        'browseId': 'FEmusic_home',
      }, profile: YoutubeClientProfile.webRemix, useAuth: false);
      final String? vd = data['responseContext']?['visitorData'] as String?;
      if (vd != null && vd.isNotEmpty) {
        await _ref.read(youtubeAuthServiceProvider).cacheVisitorData(vd);
        debugPrint('[YoutubeStreamRepo][WARM-UP] visitorData cached: ${vd.substring(0, 10)}...');
      }
    } catch (e) {
      debugPrint('[YoutubeStreamRepo][WARM-UP] Failed (non-critical): $e');
    }
  }

  void dispose() {
    _explode.close();
  }
}
