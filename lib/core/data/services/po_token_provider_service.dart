import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class PoTokenProviderService {
  Process? _process;

  Future<void> _startProcess() async {
    String execPath = p.join('python_engine', 'dist', 'bgutil-pot-windows-x86_64.exe');
    if (!File(execPath).existsSync()) {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      execPath = p.join(appDir, 'bgutil-pot-windows-x86_64.exe');
    }

    if (File(execPath).existsSync()) {
      debugPrint('[PoTokenProviderService] Starting background provider: $execPath');
      _process = await Process.start(execPath, [], runInShell: true);

      _process!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[PoTokenProviderService stdout] $data');
      });
      _process!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[PoTokenProviderService stderr] $data');
      });
    } else {
      debugPrint('[PoTokenProviderService] Warning: Provider executable not found at $execPath');
    }
  }

  Future<void> start() async {
    if (!Platform.isWindows) return;
    try {
      ServerSocket? socket;
      try {
        socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 4416);
      } catch (_) {
        // Port 4416 is occupied (socket remains null)
      }

      if (socket != null) {
        await socket.close();
        await _startProcess();
      } else {
        debugPrint('[PoTokenProviderService] Port 4416 already active.');
      }
    } catch (e) {
      debugPrint('[PoTokenProviderService] Failed to start: $e');
    }
  }

  void stop() {
    if (_process != null) {
      debugPrint('[PoTokenProviderService] Terminating background provider process.');
      _process!.kill();
      _process = null;
    }
  }
}

final poTokenProviderService = PoTokenProviderService();
