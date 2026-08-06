import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Logic isolation for the Python bridge (resonance_downloader.py).
/// Handles Process lifecycle and JSON IPC (stdin/stdout).
class DownloaderBridgeDatasource {
  Process? _process;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bridgeEvents => _eventController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  bool _isReady = false;
  bool get isReady => _isReady;

  final _pendingCommands = <String>[];
  Future<void>? _initFuture;

  Future<void> initialize() async {
    if (Platform.isAndroid) return;
    if (_process != null) return;
    return _initFuture ??= _performInitialization();
  }

  Future<void> _performInitialization() async {
    final bridge = _resolveBridge();
    debugPrint('[DownloaderBridge] Starting process: ${bridge.exe} ${bridge.args.join(' ')}');
    try {
      _process = await Process.start(
        bridge.exe,
        bridge.args,
        runInShell: Platform.isWindows,
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            debugPrint('[DownloaderBridge Process STDOUT] $line');
            _handleRawLine(line);
          });

      _stderrSub = _process!.stderr.transform(utf8.decoder).listen((line) {
        debugPrint('[DownloaderBridge Process STDERR] $line');
        if (line.contains('MISSING_DEP')) {
          _errorController.add('Python dependency missing: $line');
        }
      });

      _process!.exitCode.then((code) {
        debugPrint('[DownloaderBridge] Process exited with code: $code');
        _isReady = false;
        _process = null;
        _initFuture = null;
      });
    } catch (e) {
      debugPrint('[DownloaderBridge] Process start exception: $e');
      _initFuture = null;
      final isPython = bridge.exe == 'python';
      _errorController.add(
        'Could not start download bridge (${bridge.exe}): $e\n\n'
        '${isPython ? "Ensure Python is installed and in your PATH.\n" : ""}'
        'Try running:  python build_downloader.py  from the resonance_app/ folder to rebuild the bridge.',
      );
    }
  }

  void _handleRawLine(String line) {
    if (line.isEmpty) return;
    try {
      final Map<String, dynamic> evt = jsonDecode(line) as Map<String, dynamic>;
      
      if (evt['type'] == 'ready') {
        _isReady = true;
        for (final cmd in _pendingCommands) {
          _sendRaw(cmd);
        }
        _pendingCommands.clear();
      }
      
      _eventController.add(evt);
    } catch (e) {
      debugPrint('DownloaderBridgeDatasource: Error decoding JSON: $line');
    }
  }

  void sendCommand(Map<String, dynamic> command) {
    final jsonCmd = jsonEncode(command);
    if (!_isReady) {
      _pendingCommands.add(jsonCmd);
    } else {
      _sendRaw(jsonCmd);
    }
  }

  Future<void> _sendRaw(String line) async {
    try {
      debugPrint('[DownloaderBridge Process STDIN] Writing: $line');
      _process?.stdin.writeln(line);
      await _process?.stdin.flush();
    } catch (e) {
      debugPrint('DownloaderBridgeDatasource: Error writing to stdin: $e');
    }
  }

  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _sendRaw(jsonEncode({'action': 'quit'}));
    _process?.kill();
    _process = null;
    _isReady = false;
  }

  /// Returns exe+args for one-shot process invocation (no stdin pipe needed).
  /// Prefers raw Python script in dev mode so latest code is always used.
  ({String exe, List<String> args})? resolveBridgeForOneShot() {
    if (Platform.isAndroid) return null;

    // Dev mode: prefer Python script directly — skips old compiled .exe
    final projectRoot =
        _walkUpToProjectRoot(File(Platform.resolvedExecutable).parent) ??
        _walkUpToProjectRoot(Directory.current);

    if (projectRoot != null) {
      final devPy = p.join(projectRoot.path, 'python_engine', 'resonance_downloader.py');
      if (File(devPy).existsSync()) {
        final customPy = Platform.environment['RESONANCE_PYTHON_EXE'];
        final String pyExe;
        if (customPy != null && File(customPy).existsSync()) {
          pyExe = customPy;
          debugPrint('[DownloaderBridge] Using Python from RESONANCE_PYTHON_EXE env: $pyExe');
        } else {
          pyExe = 'python';
          debugPrint('[DownloaderBridge] RESONANCE_PYTHON_EXE not set or invalid. Falling back to system: $pyExe');
        }
        return (exe: pyExe, args: ['-u', devPy]);
      }
    }

    // Production: compiled .exe next to Resonance.exe (supports --resolve when rebuilt)
    final bridge = _resolveBridge();
    if (bridge.args.isEmpty) return (exe: bridge.exe, args: []);
    return (exe: bridge.exe, args: bridge.args);
  }

  // ── Bridge executable resolution (Moved from DownloadNotifier) ───────────────

  static Directory? _walkUpToProjectRoot(Directory start) {
    var dir = start;
    for (var i = 0; i < 10; i++) {
      if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  ({String exe, List<String> args}) _resolveBridge() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 1) Production — .exe built by PyInstaller lives next to our .exe
    final prodExe = p.join(exeDir, 'resonance_downloader.exe');
    if (File(prodExe).existsSync()) {
      return (exe: prodExe, args: []);
    }

    // 2 & 3) Dev — find project root
    final projectRoot =
        _walkUpToProjectRoot(File(Platform.resolvedExecutable).parent) ??
        _walkUpToProjectRoot(Directory.current);

    if (projectRoot != null) {
      final downloaderRoot = projectRoot.path;

      // 2) Raw Python script — PREFERRED for active development
      final devPy = p.join(downloaderRoot, 'python_engine', 'resonance_downloader.py');
      if (File(devPy).existsSync()) {
        final customPy = Platform.environment['RESONANCE_PYTHON_EXE'];
        final String pyExe;
        if (customPy != null && File(customPy).existsSync()) {
          pyExe = customPy;
          debugPrint('[DownloaderBridge] Initializing bridge via RESONANCE_PYTHON_EXE env: $pyExe');
        } else {
          pyExe = 'python';
          debugPrint('[DownloaderBridge] Initializing bridge via system python fallback: $pyExe');
        }
        return (exe: pyExe, args: ['-u', devPy]);
      }

      // 3) PyInstaller .exe already built — Fallback
      final devExe = p.join(downloaderRoot, 'python_engine', 'dist', 'resonance_downloader.exe');
      if (File(devExe).existsSync()) {
        return (exe: devExe, args: []);
      }
    }

    return (exe: 'resonance_downloader.exe', args: []);
  }

  static String? resolveFFmpegDir() {
    if (Platform.isAndroid) return null;

    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 1) Production — FFmpeg /bin folder sits next to our .exe
    final prodBin = p.join(exeDir, 'bin');
    if (Directory(prodBin).existsSync()) {
      return prodBin;
    }

    // 2) Dev — find project root and look into python_engine/bin
    final projectRoot =
        _walkUpToProjectRoot(File(Platform.resolvedExecutable).parent) ??
        _walkUpToProjectRoot(Directory.current);

    if (projectRoot != null) {
      final devBin = p.join(projectRoot.path, 'python_engine', 'bin');
      if (Directory(devBin).existsSync()) {
        return devBin;
      }
    }

    return null;
  }
}
