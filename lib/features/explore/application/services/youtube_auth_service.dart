import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/utils/crypto_utils.dart';

final youtubeAuthServiceProvider = Provider<YoutubeAuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return YoutubeAuthService(prefs);
});

class YoutubeAuthService {
  final SharedPreferences _prefs;
  
  static const String _kCookiesKey = 'yt_cookies';
  static const String _kVisitorDataKey = 'yt_visitor_data';
  static const String _kDataSyncIdKey = 'yt_datasync_id';

  YoutubeAuthService(this._prefs);

  bool get isLoggedIn => _prefs.getString(_kCookiesKey) != null;

  Future<void> saveSession({
    required Map<String, String> cookies,
    String? visitorData,
    String? dataSyncId,
  }) async {
    await _prefs.setString(_kCookiesKey, jsonEncode(cookies));
    if (visitorData != null) await _prefs.setString(_kVisitorDataKey, visitorData);
    if (dataSyncId != null) await _prefs.setString(_kDataSyncIdKey, dataSyncId);
    debugPrint('YoutubeAuthService: Session SAVED.');
  }

  /// Scans the native WebView2 cookie database using the [userDataPath].
  /// Uses "Shadow Replication" to bypass the SQLite lock during active sessions.
  Future<void> scanNativeCookies(String userDataPath) async {
    debugPrint('YoutubeAuthService: Starting Native Cookie Scan at $userDataPath');
    
    // 1. Locate the Network Cookies file (Standard Chromium/WebView2 path)
    final originalFile = File(p.join(userDataPath, 'EBWebView', 'Default', 'Network', 'Cookies'));
    if (!await originalFile.exists()) {
      debugPrint('YoutubeAuthService: [ERROR] Cookie file not found at ${originalFile.path}');
      return;
    }

    // 2. Replication: Copy to temporary directory to bypass lock
    final tempDir = await getTemporaryDirectory();
    final replicaFile = File(p.join(tempDir.path, 'Cookies_replicated'));
    
    try {
      await originalFile.copy(replicaFile.path);
      debugPrint('YoutubeAuthService: Shadow Replication SUCCESS.');

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
      
      debugPrint('YoutubeAuthService: Extracted ${nativeCookies.length} native cookies (including HttpOnly).');

      // 5. Merge with existing cookies (if any) or save as new
      final Map<String, String> currentCookies = getCookies();
      currentCookies.addAll(nativeCookies);
      
      if (currentCookies.containsKey('SAPISID') || currentCookies.containsKey('__Secure-3PAPISID')) {
        await saveSession(cookies: currentCookies);
      }

      db.close();
    } catch (e) {
      debugPrint('YoutubeAuthService: [CRITICAL] Cookie extraction failed: $e');
    } finally {
      // 6. Cleanup Guard: Always delete the replica
      if (await replicaFile.exists()) {
        try {
          await replicaFile.delete();
          debugPrint('YoutubeAuthService: Replicated cookie file CLEANED UP.');
        } catch (_) {}
      }
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_kCookiesKey);
    await _prefs.remove(_kVisitorDataKey);
    await _prefs.remove(_kDataSyncIdKey);
    debugPrint('YoutubeAuthService: Session CLEARED.');
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
