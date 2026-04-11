import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../application/services/youtube_js_engine.dart';
import '../services/youtube_innertube_client.dart';

final youtubeStreamRepositoryProvider = Provider<YoutubeStreamRepository>((ref) {
  final client = ref.watch(youtubeInnerTubeClientProvider);
  final cacheService = ref.watch(mediaCacheServiceProvider);
  final jsEngine = ref.watch(youtubeJsEngineProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  
  final repo = YoutubeStreamRepository(client, cacheService, jsEngine, prefs);
  ref.onDispose(() => repo.dispose());
  return repo;
});

enum YoutubeEngine { explodeDart, innerTube }

class YoutubeStreamRepository {
  final YoutubeInnerTubeClient _client;
  final MediaCacheService _cacheService;
  final YoutubeJsEngine _jsEngine;
  final SharedPreferences _prefs;
  final yt.YoutubeExplode _explode = yt.YoutubeExplode();

  YoutubeStreamRepository(this._client, this._cacheService, this._jsEngine, this._prefs);

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

    final engine = _getEngineSetting();
    if (engine == YoutubeEngine.innerTube) {
      return _getInnerTubeAudioStream(videoId);
    }
    
    return _searchExplodeStream(videoId);
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
      return _getInnerTubeAudioStream(videoId); // Last resort
    }
  }

  Future<String?> _getInnerTubeAudioStream(String videoId) async {
    // [V20.7 SOTA Patch] Adaptive Discovery Workflow
    // Step 1: Attempt 1 (WEB_REMIX) - Try to discover assets via API
    final firstResult = await _fetchFromInnerTube(videoId, YoutubeClientProfile.webRemix, useAuth: true, sts: null);
    
    if (firstResult != null && firstResult.streamUrl != null) {
      return firstResult.streamUrl;
    }

    // [V20.13 SOTA Patch] Embed Discovery Bypass Fallback
    String? discoveredJs = firstResult?.baseJsUrl;
    if (discoveredJs == null) {
      debugPrint('YoutubeStreamRepository: API discovery failed. Falling back to Embed Page scraping...');
      discoveredJs = await _discoverJsUrl(videoId);
    }

    if (discoveredJs == null) {
      debugPrint('YoutubeStreamRepository: [CRITICAL] All discovery methods failed.');
      return null;
    }

    // Step 2: Initialize STS from Discovered URL
    debugPrint('YoutubeStreamRepository: Discovered fresh base.js: $discoveredJs. Retrieving STS...');
    final freshSts = await _jsEngine.getSignatureTimestamp(discoveredJs);

    // Step 3: Attempt 2 (ANDROID_MUSIC) - Resolution using Dynamic STS
    debugPrint('YoutubeStreamRepository: WEB_REMIX stream failed. Rotating to ANDROID_MUSIC (Dynamic STS)...');
    final secondResult = await _fetchFromInnerTube(
      videoId, 
      YoutubeClientProfile.androidMusic, 
      useAuth: false, 
      sts: freshSts,
    );

    if (secondResult != null && secondResult.streamUrl != null) {
      return secondResult.streamUrl;
    }

    debugPrint('YoutubeStreamRepository: [CRITICAL] All InnerTube clients failed for $videoId');
    return null;
  }

  Future<({String? streamUrl, String? baseJsUrl})?> _fetchFromInnerTube(
    String videoId, 
    YoutubeClientProfile profile, {
    required bool useAuth, 
    int? sts,
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
      );

      final String? jsPath = data['assets']?['js'];
      final String? baseJsUrl = jsPath != null ? 'https://www.youtube.com$jsPath' : null;
      
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

      String? streamUrl = audioFormat['url'] as String? ?? audioFormat['signatureCipher'] as String? ?? audioFormat['cipher'] as String?;
      if (streamUrl == null) return (streamUrl: null, baseJsUrl: baseJsUrl);
      
      // [GUARDRAIL 2] Apply QuickJS n-transform decipher via YoutubeJsEngine
      final String? n = audioFormat['n'] as String? ?? _extractNFromUrl(streamUrl);
      if (n != null && baseJsUrl != null) {
        debugPrint('YoutubeStreamRepository: Applying n-transform deciphering for ${profile.name}.');
        final decipheredN = await _jsEngine.decipherN(n, baseJsUrl);
        streamUrl = _replaceNInUrl(streamUrl, n, decipheredN);
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

  String? _extractNFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['n'];
    } catch (_) {
      return null;
    }
  }

  String _replaceNInUrl(String url, String oldN, String newN) {
    return url.replaceFirst('n=$oldN', 'n=$newN');
  }

  void dispose() {
    _explode.close();
  }

  /// [V20.14 SOTA Patch] The Homepage Anchor
  /// Scrapes the main YouTube Homepage to find the active player JS.
  /// Reverted from Embed/Iframe API to ensure 100% reliability for Official Tracks.
  Future<String?> _discoverJsUrl(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.youtube.com/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          // [V20.12 SOTA Patch] GDPR/EU Consent Bypass Guard
          'Cookie': 'CONSENT=YES+cb; SOCS=CAI+BHVuaXQ+',
          'Accept': '*/*',
        },
      );
      
      if (response.statusCode != 200) return null;

      // [V20.14 SOTA Patch] Indestructible Regex (JS Discovery Guard)
      // Highly permissive pattern to handle dynamic player folder structures.
      final regex = RegExp(r'''(/|\\/)?s(/|\\/)player(/|\\/)[a-zA-Z0-9_-]+(/|\\/)[^\s"'\>]+base\.js''');
      final match = regex.firstMatch(response.body);
      
      if (match != null) {
        // [V20.11 SOTA Patch] URL Sanitization
        final path = match.group(0)!
            .replaceAll(r'\/', '/')
            .replaceAll(r'\', '/');
        return 'https://www.youtube.com$path';
      }

      return null;
    } catch (e) {
      debugPrint('YoutubeStreamRepository: Homepage discovery ERROR: $e');
      return null;
    }
  }
}
