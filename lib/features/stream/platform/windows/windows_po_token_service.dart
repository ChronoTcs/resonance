import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../domain/interfaces/i_platform_po_token_service.dart';
import '../../domain/models/po_token_pair.dart';

// ── Windows-only PoToken Provider ────────────────────────────────────────────
// Migrated from: lib/core/data/services/po_token_provider_service.dart
// Platform isolation: ONLY imported via windows_stream_provider.dart.
// No Android / Web imports allowed in this file.
class WindowsPoTokenService implements IPlatformPoTokenService {
  static final WindowsPoTokenService instance = WindowsPoTokenService._internal();
  factory WindowsPoTokenService() => instance;
  WindowsPoTokenService._internal();

  String? _cachedPoToken;
  DateTime? _cachedExpiresAt;
  Timer? _keeperTimer;
  bool _isGenerating = false;

  String? get activePoToken {
    if (_cachedExpiresAt != null &&
        DateTime.now().toUtc().isAfter(_cachedExpiresAt!)) {
      return null;
    }
    return _cachedPoToken;
  }

  /// Starts the initial token generation and launches the keeper daemon.
  Future<void> start() async {
    await generateFreshToken();
    _startKeeperDaemon();
  }

  Future<String?> generateFreshToken() async {
    if (_isGenerating) return _cachedPoToken;
    _isGenerating = true;

    try {
      String execPath = p.join('python_engine', 'dist', 'bgutil-pot-windows-x86_64.exe');
      if (!File(execPath).existsSync()) {
        final appDir = File(Platform.resolvedExecutable).parent.path;
        execPath = p.join(appDir, 'bgutil-pot-windows-x86_64.exe');
      }

      if (!File(execPath).existsSync()) {
        debugPrint('[WindowsPoTokenService] Executable not found at $execPath');
        _isGenerating = false;
        return null;
      }

      debugPrint('[WindowsPoTokenService] Executing bgutil process: $execPath');
      final result = await Process.run(execPath, [], runInShell: true)
          .timeout(const Duration(seconds: 10));

      if (result.exitCode == 0 && result.stdout != null) {
        final stdout = (result.stdout as String).trim();
        for (final line in stdout.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            try {
              final data = jsonDecode(trimmed) as Map<String, dynamic>;
              final token = (data['poToken'] ?? data['po_token']) as String?;
              final expiresAtStr = data['expiresAt'] as String?;
              if (token != null && token.isNotEmpty) {
                _cachedPoToken = token;
                _cachedExpiresAt = expiresAtStr != null
                    ? DateTime.tryParse(expiresAtStr)?.toUtc()
                    : DateTime.now().toUtc().add(const Duration(hours: 1));
                debugPrint('[WindowsPoTokenService] PoToken acquired, valid until $_cachedExpiresAt');
                _isGenerating = false;
                return _cachedPoToken;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[WindowsPoTokenService] Generation failed: $e');
    }
    _isGenerating = false;
    return _cachedPoToken;
  }

  void _startKeeperDaemon() {
    _keeperTimer?.cancel();
    _keeperTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final now = DateTime.now().toUtc();
      if (_cachedExpiresAt == null ||
          _cachedExpiresAt!.difference(now).inMinutes <= 15) {
        debugPrint('[WindowsPoTokenService] Token expiring — refreshing...');
        await generateFreshToken();
      }
    });
  }

  void stop() => _keeperTimer?.cancel();

  // ── IPlatformPoTokenService ────────────────────────────────────────────────

  @override
  Future<PoTokenPair?> getPoToken(String visitorData, {String? videoId}) async {
    final active = activePoToken;
    if (active != null && active.isNotEmpty) {
      return PoTokenPair(playerPoToken: active, streamPoToken: active);
    }
    final fresh = await generateFreshToken();
    if (fresh != null && fresh.isNotEmpty) {
      return PoTokenPair(playerPoToken: fresh, streamPoToken: fresh);
    }
    return null;
  }

  /// Windows uses yt-dlp for cipher handling — not in-app. Returns null.
  @override
  Future<String?> decipherSignature(String signatureCipher, String videoId) async => null;

  /// Windows uses yt-dlp for n-param handling — not in-app. Returns null.
  @override
  Future<String?> decipherN(String url) async => null;

  /// Windows fetches STS via HTTP JS scrape in YoutubeAuthService. Returns null here.
  @override
  Future<int?> getSignatureTimestamp() async => null;
}
