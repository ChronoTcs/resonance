import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/utils/crypto_utils.dart';
import '../../../stream/application/platform_stream_provider.dart';

final youtubeAuthServiceProvider = Provider<YoutubeAuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return YoutubeAuthService(
    prefs,
    getNativeSignatureTimestamp: () =>
        ref.read(platformPoTokenServiceProvider).getSignatureTimestamp(),
  );
});

class YoutubeAuthService {
  final SharedPreferences _prefs;
  final Future<int?> Function()? getNativeSignatureTimestamp;
  
  static const String _kCookiesKey = 'yt_cookies';
  static const String _kVisitorDataKey = 'yt_visitor_data';
  static const String _kDataSyncIdKey = 'yt_datasync_id';
  static const int _kDefaultSts = 20697;
  static const String _kStsKey = 'yt_sts';
  static const String _apiKey = 'AIzaSyC15S986sV10pNo757C36Wq71986sV10pN';

  YoutubeAuthService(
    this._prefs, {
    this.getNativeSignatureTimestamp,
  });

  bool get isLoggedIn => _prefs.getString(_kCookiesKey) != null;

  Future<void> saveSession({
    required Map<String, String> cookies,
    String? visitorData,
    String? dataSyncId,
  }) async {
    await _prefs.setString(_kCookiesKey, jsonEncode(cookies));
    if (visitorData != null) await _prefs.setString(_kVisitorDataKey, visitorData);
    if (dataSyncId != null) await _prefs.setString(_kDataSyncIdKey, dataSyncId);
    debugPrint('[YoutubeAuth] Session SAVED.');
  }

  /// Scans the native WebView2 cookie database using the [userDataPath].
  /// Uses "Shadow Replication" to bypass the SQLite lock during active sessions.
  Future<void> scanNativeCookies(String userDataPath) async {
    debugPrint('[YoutubeAuth] Starting Native Cookie Scan at $userDataPath');
    
    // 1. Locate the Network Cookies file (Standard Chromium/WebView2 path)
    final originalFile = File(p.join(userDataPath, 'EBWebView', 'Default', 'Network', 'Cookies'));
    if (!await originalFile.exists()) {
      debugPrint('[YoutubeAuth] [ERROR] Cookie file not found at ${originalFile.path}');
      return;
    }

    // 2. Replication: Copy to temporary directory to bypass lock
    final tempDir = await getTemporaryDirectory();
    final replicaFile = File(p.join(tempDir.path, 'Cookies_replicated'));
    
    try {
      await originalFile.copy(replicaFile.path);
      debugPrint('[YoutubeAuth] Shadow Replication SUCCESS.');

      // 3. Open SQLite Replica
      final db = sqlite3.open(replicaFile.path);
      
      // 4. Query for YouTube/Google cookies (including HttpOnly)
      final ResultSet results = db.select('''
        SELECT name, value, host_key FROM cookies 
        WHERE host_key LIKE '%.youtube.com' OR host_key LIKE '%.google.com'
      ''');

      final Map<String, String> nativeCookies = {};
      for (final row in results) {
        nativeCookies[row['name'] as String] = row['value'] as String;
      }
      
      debugPrint('[YoutubeAuth] Extracted ${nativeCookies.length} native cookies (including HttpOnly).');

      // 5. Merge with existing cookies (if any) or save as new
      final Map<String, String> currentCookies = getCookies();
      currentCookies.addAll(nativeCookies);
      
      if (currentCookies.containsKey('SAPISID') || currentCookies.containsKey('__Secure-3PAPISID')) {
        await saveSession(cookies: currentCookies);
      }

      db.close();
    } catch (e) {
      debugPrint('[YoutubeAuth] [CRITICAL] Cookie extraction failed: $e');
    } finally {
      // 6. Cleanup Guard: Always delete the replica
      if (await replicaFile.exists()) {
        try {
          await replicaFile.delete();
          debugPrint('[YoutubeAuth] Replicated cookie file CLEANED UP.');
        } catch (_) {}
      }
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_kCookiesKey);
    await _prefs.remove(_kVisitorDataKey);
    await _prefs.remove(_kDataSyncIdKey);
    debugPrint('[YoutubeAuth] Session CLEARED.');
  }

  Map<String, String> getCookies() {
    final String? json = _prefs.getString(_kCookiesKey);
    if (json == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(json));
    } catch (_) {
      return {};
    }
  }

  String? get visitorData => _prefs.getString(_kVisitorDataKey);
  String? get dataSyncId => _prefs.getString(_kDataSyncIdKey);

  int get signatureTimestamp => _prefs.getInt(_kStsKey) ?? _kDefaultSts;

  Future<void> updateSignatureTimestamp(int sts) async {
    if (sts > 0) {
      await _prefs.setInt(_kStsKey, sts);
      debugPrint('[YoutubeAuth] Updated signatureTimestamp: $sts');
    }
  }

  /// Refreshes signatureTimestamp from YouTube embed player JS in the background
  Future<int> refreshSignatureTimestamp() async {
    try {
      final getSts = getNativeSignatureTimestamp;
      if (getSts != null) {
        final nativeSts = await getSts();
        if (nativeSts != null && nativeSts > 0) {
          await updateSignatureTimestamp(nativeSts);
          return nativeSts;
        }
      }

      final res = await http.get(
        Uri.parse('https://www.youtube.com/s/player/f572e43c/player_embed.vflset/id_ID/base.js'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/140.0'},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final match = RegExp(r'signatureTimestamp[=:](\d+)').firstMatch(res.body);
        if (match != null) {
          final sts = int.parse(match.group(1)!);
          await updateSignatureTimestamp(sts);
          return sts;
        }
      }
    } catch (e) {
      debugPrint('[YoutubeAuth] Could not dynamically refresh signatureTimestamp: $e');
    }
    return signatureTimestamp;
  }

  /// Caches a real visitorData fetched from YouTube InnerTube response.
  Future<void> cacheVisitorData(String visitorData) async {
    if (visitorData.isNotEmpty) {
      await _prefs.setString(_kVisitorDataKey, visitorData);
    }
  }

  /// Guarantees that a valid visitorData exists. If not cached, fetches one synchronously from InnerTube.
  Future<String> ensureVisitorData() async {
    final cached = visitorData;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      debugPrint('[YoutubeAuth] Fetching fresh visitorData from YouTube...');
      final response = await http.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/visitor_id?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20260707.12.00',
              'hl': 'en',
              'gl': 'US',
            }
          }
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? vd = data['responseContext']?['visitorData'] as String?;
        if (vd != null && vd.isNotEmpty) {
          await cacheVisitorData(vd);
          debugPrint('[YoutubeAuth] Acquired visitorData: ${vd.substring(0, 12)}...');
          return vd;
        }
      }
    } catch (e) {
      debugPrint('[YoutubeAuth] ensureVisitorData failed: $e');
    }
    return '';
  }

  /// Builds the authenticated headers for InnerTube requests.
  /// Includes SAPISIDHASH if cookies are available.
  Map<String, String> getAuthenticatedHeaders() {
    final Map<String, String> cookies = getCookies();
    if (cookies.isEmpty) return {};

    final String cookieString = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    final Map<String, String> headers = {
      'Cookie': cookieString,
      'X-Goog-AuthUser': '0',
      'X-Origin': 'https://music.youtube.com',
      'Origin': 'https://music.youtube.com',
      'User-Agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    };

    // Calculate SAPISIDHASH if SAPISID is present
    final String? sapiSid = cookies['SAPISID'] ?? cookies['__Secure-3PAPISID'];
    if (sapiSid != null) {
      headers['Authorization'] = CryptoUtils.generateSapiSidHash(sapiSid, 'https://music.youtube.com');
    }

    return headers;
  }

  /// Helper to extract cookies from a raw string (e.g. document.cookie)
  Map<String, String> parseCookies(String cookieString) {
    final Map<String, String> cookieMap = {};
    for (var cookie in cookieString.split(';')) {
      final parts = cookie.split('=');
      if (parts.length >= 2) {
        cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
    return cookieMap;
  }
}
