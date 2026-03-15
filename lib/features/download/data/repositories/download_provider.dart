import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/download/data/models/download_item.dart';
import 'package:resonance_app/features/download/data/repositories/download_settings_provider.dart';

// ─── Public provider ────────────────────────────────────────────────────────
final downloadProvider = NotifierProvider<DownloadNotifier, List<DownloadItem>>(
  DownloadNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────
class DownloadNotifier extends Notifier<List<DownloadItem>> {
  // ── Bridge executable resolution ──────────────────────────────────────────
  //
  // Lookup order (first match wins):
  //  1. Production: resonance_downloader.exe next to our own .exe
  //     → Created by PyInstaller, copied here by CMakeLists install rule.
  //  2. Dev (PyInstaller already run): .exe in downloader/dist/
  //  3. Dev (Python available): .py script alongside a local resonance_downloader.py
  //
  // Returns a tuple: (executable, arguments)
  static Directory? _walkUpToProjectRoot(Directory start) {
    var dir = start;
    for (var i = 0; i < 10; i++) {
      if (File('${dir.path}\\pubspec.yaml').existsSync()) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static ({String exe, List<String> args}) _resolveBridge() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 1) Production — .exe built by PyInstaller lives next to our .exe
    final prodExe = '$exeDir\\resonance_downloader.exe';
    if (File(prodExe).existsSync()) {
      return (exe: prodExe, args: []);
    }

    // 2 & 3) Dev — find project root by walking up from the exe dir OR
    //         from Directory.current (which is the project root during `flutter run`)
    final projectRoot =
        _walkUpToProjectRoot(File(Platform.resolvedExecutable).parent) ??
        _walkUpToProjectRoot(Directory.current);

    if (projectRoot != null) {
      // The downloader/ folder sits next to resonance_app/ (i.e., projectRoot.parent)
      final downloaderRoot = projectRoot.parent.path;

      // 2) Raw Python script — PREFERRED for active development (zero-setup)
      final devPy = '$downloaderRoot\\python_engine\\resonance_downloader.py';
      if (File(devPy).existsSync()) {
        return (exe: 'python', args: [devPy]);
      }

      // 3) PyInstaller .exe already built — Fallback if script is missing
      final devExe =
          '$downloaderRoot\\python_engine\\dist\\resonance_downloader.exe';
      if (File(devExe).existsSync()) {
        return (exe: devExe, args: []);
      }
    }

    // Absolute fallback — will fail gracefully in _launchBridge
    return (exe: 'resonance_downloader.exe', args: []);
  }

  Process? _process;
  StreamSubscription? _stdoutSub;
  bool _bridgeReady = false;
  final _pendingCommands = <String>[];

  int get _maxConcurrent {
    final s = ref.read(downloadSettingsProvider).value;
    return s?.maxConcurrent ?? 2;
  }

  @override
  List<DownloadItem> build() {
    ref.onDispose(_teardown);
    _launchBridge();
    return [];
  }

  // ── Bridge lifecycle ───────────────────────────────────────────────────────

  Future<void> _launchBridge() async {
    final bridge = _resolveBridge();
    try {
      _process = await Process.start(
        bridge.exe,
        bridge.args,
        runInShell: bridge.exe == 'python',
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleEvent);

      _process!.stderr.transform(utf8.decoder).listen((line) {
        if (line.contains('MISSING_DEP')) {
          _emitGlobalError('Python dependency missing: $line');
        }
      });
    } catch (e) {
      final isPython = bridge.exe == 'python';
      _emitGlobalError(
        'Could not start download bridge (${bridge.exe}): $e\n\n'
        '${isPython ? "Ensure Python is installed and in your PATH.\n" : ""}'
        'Try running:  python build_downloader.py  from the resonance_app/ folder to rebuild the bridge.',
      );
    }
  }

  void _teardown() {
    _stdoutSub?.cancel();
    _sendRaw('{"action":"quit"}');
    _process?.kill();
    _process = null;
    _bridgeReady = false;
  }

  // ── Event handling ─────────────────────────────────────────────────────────

  void _handleEvent(String line) {
    if (line.isEmpty) return;
    Map<String, dynamic> evt;
    try {
      evt = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = evt['type'] as String? ?? '';
    if (type == 'ready') {
      _bridgeReady = true;
      for (final cmd in _pendingCommands) {
        _sendRaw(cmd);
      }
      _pendingCommands.clear();
      return;
    }

    final id = evt['id'] as String? ?? '';

    switch (type) {
      case 'progress':
        _updateItem(
          id,
          (item) => item.copyWith(
            status: DownloadStatus.downloading,
            progress: (evt['percent'] as num?)?.toDouble() ?? item.progress,
            speed: evt['speed'] as String?,
            eta: (evt['eta'] as num?)?.toInt(),
          ),
        );
        break;
      case 'done':
        _updateItem(
          id,
          (item) => item.copyWith(
            status: DownloadStatus.done,
            progress: 100.0,
            resolvedTitle: evt['title'] as String?,
            outputPath: evt['path'] as String?,
          ),
        );
        // Kick off next queued download
        _scheduleNext();
        break;
      case 'lyrics':
        final status = evt['status'] as String? ?? 'unknown';
        final message = status == 'found'
            ? '🎵 Lyrics found and saved.'
            : (status == 'not_found'
                  ? '❌ Lyrics not found.'
                  : '⚠ Lyrics error: ${evt['message']}');
        _updateItem(id, (item) => item.copyWith(logs: [...item.logs, message]));
        break;
      case 'log':
        final msg = evt['message'] as String? ?? '';
        _updateItem(
          id,
          (item) => item.copyWith(
            status: DownloadStatus.downloading,
            statusMessage: msg,
            logs: [...item.logs, msg],
          ),
        );
        break;
      case 'error':
        _updateItem(
          id,
          (item) => item.copyWith(
            status: DownloadStatus.error,
            errorMessage: evt['message'] as String?,
          ),
        );
        _scheduleNext();
        break;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Add one or many URLs/queries to the queue.
  void addToQueue(
    List<String> urls, {
    DownloadType type = DownloadType.audio,
    DownloadSource source = DownloadSource.ytmusic,
  }) {
    final newItems = urls
        .map(
          (url) => DownloadItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_${url.hashCode}',
            url: url,
            displayTitle: url,
            type: type,
            source: source,
          ),
        )
        .toList();
    state = [...state, ...newItems];
    _scheduleNext();
  }

  void cancelItem(String id) {
    _updateItem(id, (item) => item.copyWith(status: DownloadStatus.cancelled));
    // We can't easily kill a single thread inside the bridge; mark as cancelled
    // and skip it in scheduleNext
  }

  void clearCompleted() {
    state = state
        .where(
          (i) =>
              i.status != DownloadStatus.done &&
              i.status != DownloadStatus.error &&
              i.status != DownloadStatus.cancelled,
        )
        .toList();
  }

  // ── Scheduling ─────────────────────────────────────────────────────────────

  void _scheduleNext() {
    final active = state
        .where((i) => i.status == DownloadStatus.downloading)
        .length;
    if (active >= _maxConcurrent) return;

    final queued = state
        .where((i) => i.status == DownloadStatus.queued)
        .toList();
    final toStart = queued.take(_maxConcurrent - active);

    for (final item in toStart) {
      _startDownload(item); // Unawaited execution is fine here to allow parallel starts
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    _updateItem(item.id, (i) => i.copyWith(status: DownloadStatus.downloading));

    // Wait until settings are loaded to guarantee customized paths are respected
    final settings = await ref.read(downloadSettingsProvider.future);

    // If settings haven't loaded yet, we can still proceed using the defaults.
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final musicPath = (settings.musicOutputPath.isNotEmpty == true)
        ? settings.musicOutputPath
        : '$home\\Music\\Resonance Downloads';
    final videoPath = (settings.videoOutputPath.isNotEmpty == true)
        ? settings.videoOutputPath
        : '$home\\Videos\\Resonance Downloads';
    // Lyrics path defaults to a sub-folder inside the music path
    final lyricsPath = (settings.lyricsOutputPath.isNotEmpty == true)
        ? settings.lyricsOutputPath
        : '$musicPath\\Lyrics';

    String sourceStr;
    switch (item.source) {
      case DownloadSource.ytmusic:
        sourceStr = 'ytmusic';
        break;
      case DownloadSource.youtube:
        sourceStr = 'youtube';
        break;
      case DownloadSource.auto:
        sourceStr = item.url.startsWith('http') ? 'url' : 'ytmusic';
        break;
    }

    final cmd = jsonEncode({
      'action': 'download',
      'id': item.id,
      'url': item.url,
      'type': item.type == DownloadType.audio ? 'audio' : 'video',
      'source': sourceStr,
      'music_path': musicPath,
      'video_path': videoPath,
      'lyrics_path': lyricsPath,
      'quality': settings.audioQuality,
      'max_retries': settings.maxRetries,
      'socket_timeout': settings.connectionTimeout,
      'concurrent_fragments': settings.fragmentsPerDownload,
    });

    _sendCommand(cmd);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _sendCommand(String jsonCmd) {
    if (!_bridgeReady) {
      _pendingCommands.add(jsonCmd);
    } else {
      _sendRaw(jsonCmd);
    }
  }

  void _sendRaw(String line) {
    try {
      _process?.stdin.writeln(line);
    } catch (_) {}
  }

  void _updateItem(String id, DownloadItem Function(DownloadItem) updater) {
    state = [
      for (final item in state)
        if (item.id == id) updater(item) else item,
    ];
  }

  void _emitGlobalError(String message) {
    // Just log; no specific item to attach the error to
    // ignore: avoid_print
    print('[DownloadNotifier] ERROR: $message');
  }
}
