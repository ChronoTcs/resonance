import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class PoTokenProviderService {
  String? _cachedPoToken;
  DateTime? _cachedExpiresAt;
  Timer? _keeperTimer;
  bool _isGenerating = false;

  String? get activePoToken {
    if (_cachedExpiresAt != null && DateTime.now().toUtc().isAfter(_cachedExpiresAt!)) {
      return null;
    }
    return _cachedPoToken;
  }

  Future<void> start() async {
    if (!Platform.isWindows) return;
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
        debugPrint('[PoTokenProviderService] Executable not found at $execPath');
        _isGenerating = false;
        return null;
      }

      debugPrint('[PoTokenProviderService] Executing bgutil process: $execPath');
      final result = await Process.run(execPath, [], runInShell: true).timeout(const Duration(seconds: 10));

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
                if (expiresAtStr != null) {
                  _cachedExpiresAt = DateTime.tryParse(expiresAtStr)?.toUtc();
                } else {
                  _cachedExpiresAt = DateTime.now().toUtc().add(const Duration(hours: 1));
                }
                debugPrint('[PoTokenProviderService] ✅ Fresh PoToken acquired! Valid until: ${_cachedExpiresAt?.toLocal()} (Local Time)');
                _isGenerating = false;
                return _cachedPoToken;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[PoTokenProviderService] Generation exception: $e');
    }
    _isGenerating = false;
    return _cachedPoToken;
  }

  void _startKeeperDaemon() {
    _keeperTimer?.cancel();
    _keeperTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final now = DateTime.now().toUtc();
      if (_cachedExpiresAt == null || _cachedExpiresAt!.difference(now).inMinutes <= 15) {
        debugPrint('[PoTokenProviderService Keeper] Token expiring or missing. Refreshing in background...');
        await generateFreshToken();
      } else {
        debugPrint('[PoTokenProviderService Keeper] PoToken active & valid until $_cachedExpiresAt');
      }
    });
  }

  void stop() {
    _keeperTimer?.cancel();
  }
}

final poTokenProviderService = PoTokenProviderService();
