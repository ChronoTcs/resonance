import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/data/services/data_usage_service.dart';
import '../../application/services/youtube_auth_service.dart';

final youtubeInnerTubeClientProvider = Provider<YoutubeInnerTubeClient>((ref) {
  final authService = ref.watch(youtubeAuthServiceProvider);
  final dataUsageService = ref.watch(dataUsageServiceProvider);
  return YoutubeInnerTubeClient(authService, dataUsageService);
});

enum YoutubeClientProfile {
  webRemix,      // YouTube Music Web
  androidMusic,  // YouTube Music Android
  android,       // YouTube Main Android
}

class YoutubeInnerTubeClient {
  final YoutubeAuthService _authService;
  final DataUsageService _dataUsageService;
  
  static const String _apiKey = 'AIzaSyC15S986sV10pNo757C36Wq71986sV10pN';

  YoutubeInnerTubeClient(this._authService, this._dataUsageService);

  Future<Map<String, dynamic>> post(
    String endpoint, 
    Map<String, dynamic> payload, {
    YoutubeClientProfile profile = YoutubeClientProfile.webRemix,
    bool useAuth = false,
    int? signatureTimestamp,
  }) async {
    const apiKey = _apiKey;
    
    // [V20.16 SOTA Patch] Dynamic API Routing
    // webRemix optimized for music.youtube.com, while androidMusic uses googleapis endpoint.
    final String targetBaseUrl = (profile == YoutubeClientProfile.webRemix)
        ? 'https://music.youtube.com/youtubei/v1'
        : 'https://youtubei.googleapis.com/youtubei/v1';

    final url = '$targetBaseUrl/$endpoint?key=$apiKey';

    // [V20.15 SOTA] Explicit Typing Guard
    payload['context'] = _buildContext(profile, useAuth);

    // [V20.12 SOTA] Safe STS Injection
    if (signatureTimestamp != null) {
      payload['playbackContext'] ??= <String, dynamic>{};
      payload['playbackContext']['contentPlaybackContext'] ??= <String, dynamic>{};
      payload['playbackContext']['contentPlaybackContext']['signatureTimestamp'] = signatureTimestamp;
    }

    final response = await http.post(
      Uri.parse(url),
      headers: _buildHeaders(profile, useAuth),
      body: jsonEncode(payload),
    );

    _dataUsageService.addBytes(response.bodyBytes.length);

    if (response.statusCode != 200) {
      throw Exception('InnerTube error ($endpoint) [${profile.name}]: ${response.statusCode}');
    }

    return jsonDecode(response.body);
  }

  Map<String, String> _buildHeaders(YoutubeClientProfile profile, bool useAuth) {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (useAuth) {
      headers.addAll(_authService.getAuthenticatedHeaders());
    }

    switch (profile) {
      case YoutubeClientProfile.webRemix:
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
        headers['Origin'] = 'https://music.youtube.com';
        headers['Referer'] = 'https://music.youtube.com/';
        break;
      case YoutubeClientProfile.androidMusic:
        headers['User-Agent'] = 'com.google.android.apps.youtube.music/6.43.52 (Linux; U; Android 12; en_US) gzip';
        break;
      case YoutubeClientProfile.android:
        headers['User-Agent'] = 'com.google.android.youtube/19.08.35 (Linux; U; Android 12; en_US) gzip';
        break;
    }

    return headers;
  }

  // [V20.16 SOTA Patch] Identity Stripping Guard
  // Only injects visitorData if useAuth is true to prevent Identity Mismatch.
  Map<String, dynamic> _buildContext(YoutubeClientProfile profile, bool useAuth) {
    String clientName = "WEB_REMIX";
    String clientVersion = "1.20240313.01.00";
    String? osName;
    String? osVersion;
    String? androidSdkVersion;

    switch (profile) {
      case YoutubeClientProfile.androidMusic:
        clientName = "ANDROID_MUSIC";
        clientVersion = "6.43.52";
        osName = "Android";
        osVersion = "12";
        androidSdkVersion = "31";
        break;
      case YoutubeClientProfile.webRemix:
        clientName = "WEB_REMIX";
        clientVersion = "1.20240313.01.00";
        break;
      case YoutubeClientProfile.android:
        clientName = "ANDROID";
        clientVersion = "19.08.35";
        osName = "Android";
        osVersion = "12";
        androidSdkVersion = "31";
        break;
    }

    return <String, dynamic>{
      "client": <String, dynamic>{
        "clientName": clientName,
        "clientVersion": clientVersion,
        if (useAuth && _authService.visitorData != null) "visitorData": _authService.visitorData,
        "hl": "en",
        "gl": "US",
        "utcOffsetMinutes": 0,
        if (osName != null) "osName": osName,
        if (osVersion != null) "osVersion": osVersion,
        if (androidSdkVersion != null) "androidSdkVersion": androidSdkVersion,
        if (profile != YoutubeClientProfile.webRemix) "platform": "MOBILE",
      }
    };
  }

  String? getText(dynamic node) {
    if (node == null) return null;
    if (node['runs'] != null) {
      return (node['runs'] as List).map((r) => r['text'] as String).join();
    }
    if (node['simpleText'] != null) {
      return node['simpleText'] as String;
    }
    return null;
  }
}
