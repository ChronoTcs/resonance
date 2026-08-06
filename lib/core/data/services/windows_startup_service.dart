import 'dart:io';
import 'package:flutter/foundation.dart';

/// Helper service to manage Windows registry entry for launch at startup.
class WindowsStartupService {
  static const String _registryKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _appName = 'Resonance';

  /// Enables launch at startup by writing to Windows Registry.
  static Future<bool> enableStartup() async {
    if (!Platform.isWindows) return false;
    try {
      final exePath = Platform.resolvedExecutable;
      final result = await Process.run(
        'reg',
        [
          'add',
          _registryKey,
          '/v',
          _appName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[WindowsStartupService] Failed to enable startup: $e');
      return false;
    }
  }

  /// Disables launch at startup by removing the registry key.
  static Future<bool> disableStartup() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'reg',
        [
          'delete',
          _registryKey,
          '/v',
          _appName,
          '/f',
        ],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[WindowsStartupService] Failed to disable startup: $e');
      return false;
    }
  }

  /// Checks if the startup registry key exists.
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'reg',
        [
          'query',
          _registryKey,
          '/v',
          _appName,
        ],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
