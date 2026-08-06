import 'dart:convert';
import 'dart:ui';
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
  web,
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
    String? poToken,
    int? signatureTimestamp,
  }) async {
    const apiKey = _apiKey;
    
    String targetBaseUrl = 'https://youtubei.googleapis.com/youtubei/v1';
    if (profile == YoutubeClientProfile.webRemix) {
      targetBaseUrl = 'https://music.youtube.com/youtubei/v1';
    } else if (profile == YoutubeClientProfile.web) {
      targetBaseUrl = 'https://www.youtube.com/youtubei/v1';
    }

    final url = '$targetBaseUrl/$endpoint?key=$apiKey';

    payload['context'] = _buildContext(profile, useAuth);

    // Send poToken for WEB_REMIX or WEB. Prevents Platform Mismatch (400) on Android.
    if (poToken != null && (profile == YoutubeClientProfile.webRemix || profile == YoutubeClientProfile.web)) {
      payload['serviceIntegrityDimensions'] = <String, dynamic>{
        'poToken': poToken,
      };
    }

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

    final Map<String, dynamic> responseData = jsonDecode(response.body);
    
    // Automatically capture visitorData to maintain an anonymous preferences session
    final String? responseVisitorData = responseData['responseContext']?['visitorData'];
    if (responseVisitorData != null && responseVisitorData.isNotEmpty) {
      _authService.cacheVisitorData(responseVisitorData);
    }

    return responseData;
  }

  Map<String, String> _buildHeaders(YoutubeClientProfile profile, bool useAuth) {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Format-Version': '2',
    };

    if (useAuth) {
      headers.addAll(_authService.getAuthenticatedHeaders());
    }
    
    // Attach visitorData to headers for all tracking requests if available
    final cachedVisitor = _authService.visitorData;
    if (cachedVisitor != null && cachedVisitor.isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = cachedVisitor;
    }

    int clientNameInt = 67; // Default Web Remix
    String clientVersion = "1.20260121.03.00";

    switch (profile) {
      case YoutubeClientProfile.webRemix:
        clientNameInt = 67;
        clientVersion = "1.20260121.03.00";
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
        headers['Origin'] = 'https://music.youtube.com';
        headers['Referer'] = 'https://music.youtube.com/';
      case YoutubeClientProfile.web:
        clientNameInt = 1;
        clientVersion = "2.20240402.09.00";
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
        headers['Origin'] = 'https://www.youtube.com';
        headers['Referer'] = 'https://www.youtube.com/';
        break;
      case YoutubeClientProfile.androidMusic:
        clientNameInt = 21;
        clientVersion = "7.24.52";
        headers['User-Agent'] = 'com.google.android.apps.youtube.music/7.24.52 (Linux; U; Android 12; en_US) gzip';
        break;
      case YoutubeClientProfile.android:
        clientNameInt = 3;
        clientVersion = "21.03.36";
        headers['User-Agent'] = 'com.google.android.youtube/21.03.36 (Linux; U; Android 12; en_US) gzip';
        break;
    }

    headers['X-YouTube-Client-Name'] = clientNameInt.toString();
    headers['X-YouTube-Client-Version'] = clientVersion;

    return headers;
  }

  Map<String, dynamic> _buildContext(YoutubeClientProfile profile, bool useAuth) {
    String clientName = "WEB_REMIX";
    String clientVersion = "1.20260121.03.00";
    String? osName;
    String? osVersion;
    String? androidSdkVersion;

    switch (profile) {
      case YoutubeClientProfile.androidMusic:
        clientName = "ANDROID_MUSIC";
        clientVersion = "7.24.52";
        osName = "Android";
        osVersion = "12";
        androidSdkVersion = "31";
        break;
      case YoutubeClientProfile.webRemix:
        clientName = "WEB_REMIX";
        clientVersion = "1.20260121.03.00";
        break;
      case YoutubeClientProfile.web:
        clientName = "WEB";
        clientVersion = "2.20240402.09.00";
        break;
      case YoutubeClientProfile.android:
        clientName = "ANDROID";
        clientVersion = "21.03.36";
        osName = "Android";
        osVersion = "12";
        androidSdkVersion = "31";
        break;
    }

    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode?.isNotEmpty == true ? locale.countryCode! : "US";
    final lang = locale.languageCode.isNotEmpty == true ? locale.languageCode : "en";

    // Always attach visitorData if cached to persist the device guest session preferences
    final visitorToken = _authService.visitorData;

    return <String, dynamic>{
      "client": <String, dynamic>{
        "clientName": clientName,
        "clientVersion": clientVersion,
        if (visitorToken != null && visitorToken.isNotEmpty) "visitorData": visitorToken,
        "hl": lang,
        "gl": country,
        "utcOffsetMinutes": 0,
        "osName": osName,
        "osVersion": osVersion,
        "androidSdkVersion": androidSdkVersion,
        if (profile != YoutubeClientProfile.webRemix && profile != YoutubeClientProfile.web) "platform": "MOBILE",
      }
    };
  }

  String getUserAgent(YoutubeClientProfile profile) {
    switch (profile) {
      case YoutubeClientProfile.webRemix:
      case YoutubeClientProfile.web:
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
      case YoutubeClientProfile.androidMusic:
        return 'com.google.android.apps.youtube.music/7.24.52 (Linux; U; Android 12; en_US) gzip';
      case YoutubeClientProfile.android:
        return 'com.google.android.youtube/21.03.36 (Linux; U; Android 12; en_US) gzip';
    }
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
