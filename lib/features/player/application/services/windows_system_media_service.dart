import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:window_manager/window_manager.dart';
import '../../../library/data/models/media_item.dart';

final windowsSystemMediaServiceProvider = Provider<WindowsSystemMediaService>((
  ref,
) {
  return WindowsSystemMediaService();
});

class WindowsSystemMediaService with WindowListener {
  VoidCallback? _onPlay;
  VoidCallback? _onPause;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;


  bool _isTaskbarReady = false;
  Timer? _readinessTimer;

  WindowsSystemMediaService();

  Future<void> initialize({
    VoidCallback? onPlay,
    VoidCallback? onPause,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    VoidCallback? onStop,
  }) async {
    if (!Platform.isWindows) return;
    
    _onPlay = onPlay;
    _onPause = onPause;
    _onNext = onNext;
    _onPrevious = onPrevious;


    _readinessTimer?.cancel();
    _readinessTimer = Timer(const Duration(milliseconds: 2500), () {
      _isTaskbarReady = true;
      debugPrint(
        '[WindowsTaskbar] HWND stabilization complete. Taskbar ready.',
      );
    });

    // Listen for Window Events to sync Taskbar state (Show/Restore)
    windowManager.addListener(this);
  }

  void setCallbacks({
    VoidCallback? onPlay,
    VoidCallback? onPause,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    VoidCallback? onStop,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onNext = onNext;
    _onPrevious = onPrevious;

  }

  String? _lastSMTCTitle;
  String? _lastSMTCArtist;
  String? _lastSMTCThumb;
  bool? _lastTaskbarPlayingState;
  DateTime? _lastSyncRequestTime; // [V18.8] Anti-Spam Guard
  bool _wasHiddenToTray = false; // [V19.4] Minimize vs Hidden differentiator

  Future<void> updateMetadata(
    MediaItem? track,
    bool isPlaying, {
    String? overrideThumbnailUrl,
  }) async {
    if (!Platform.isWindows) return;

    try {
      if (track == null) {
        _lastSMTCTitle = null;
        _lastSMTCArtist = null;
        _lastSMTCThumb = null;
        if (Platform.isWindows) {
          await windowManager.setTitle('Resonance');
        }
        return;
      }

      // --- LOGIKA CERDAS DETEKSI PATH THUMBNAIL ---
      String? formattedThumbnail;
      if (overrideThumbnailUrl != null &&
          overrideThumbnailUrl.startsWith('http')) {
        formattedThumbnail = overrideThumbnailUrl;
      } else if (track.thumbnailUrl != null &&
          track.thumbnailUrl!.startsWith('http')) {
        formattedThumbnail = track.thumbnailUrl;
      } else if (track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty) {
        final cleanPath = File(track.thumbnailUrl!).absolute.path;
        if (File(cleanPath).existsSync()) {
          formattedThumbnail = Uri.file(cleanPath).toString();
        }
      }

      // CEGAH UPDATE BERULANG (FLICKER)
      if (_lastSMTCTitle == track.title &&
          _lastSMTCArtist == track.artist &&
          _lastSMTCThumb == formattedThumbnail) {
        await _updateTaskbarThumbnail(isPlaying);
        return;
      }

      _lastSMTCTitle = track.title;
      _lastSMTCArtist = track.artist;
      _lastSMTCThumb = formattedThumbnail;

      if (Platform.isWindows) {
        await windowManager.setTitle(
          '${track.title} - ${track.artist ?? 'Unknown Artist'} | Resonance',
        );
      }

      await _updateTaskbarThumbnail(isPlaying);
    } catch (e) {
      debugPrint("Metadata update error: $e");
    }
  }

  Future<void> updatePlaybackStatus(bool isPlaying) async {
    if (!Platform.isWindows) return;
    try {
      await _updateTaskbarThumbnail(isPlaying);
    } catch (e) {
      debugPrint("Taskbar status update error: $e");
    }
  }

  /// [V18.4 SOTA] Public Force Sync for Taskbar.
  /// Bypasses caches to rebuild the native thumbnail toolbar.
  Future<void> forceSyncTaskbar(MediaItem track, bool isPlaying) async {
    if (!Platform.isWindows) return;
    _lastTaskbarPlayingState = null; // Invalidate cache
    await _updateTaskbarThumbnail(isPlaying, force: true);
  }

  Future<void> updateTimeline(Duration position, Duration duration) async {
    if (!Platform.isWindows) return;

    try {
      if (duration.inMilliseconds > 0) {
        // [V18.1] GUARD: Only set progress if taskbar button is visible
        if (await windowManager.isVisible()) {
          await WindowsTaskbar.setProgress(
            position.inMilliseconds,
            duration.inMilliseconds,
          );
        }
      }
    } catch (e) {
      // [V18.1 SOTA] Suppress -1 errors when minimized/hidden
      if (e is! PlatformException) {
        debugPrint("Taskbar timeline update error: $e");
      }
    }
  }

  // [V18.1 SOTA] WINDOW LIFECYCLE HANDLERS
  void onWindowHide() {
    // [V19.4] Windows menghancurkan Taskbar Button saat window di-hide (Close to Tray)
    _wasHiddenToTray = true;
  }

  @override
  void onWindowMinimize() {
    // [V19.4] Windows tetap menyimpan Taskbar Button saat di-minimize.
    // Kita set false agar tidak melakukan re-sync yang tidak perlu.
    _wasHiddenToTray = false;
  }

  @override
  void onWindowRestore() {
    // [V19.4 SOTA] Hanya lakukan sinkronisasi paksa jika window berasal dari mode 'Hidden'
    if (_wasHiddenToTray) {
      _syncTaskbarOnVisible();
      _wasHiddenToTray = false;
    }
  }

  @override
  void onWindowFocus() {
    // Jangan lakukan apa pun pada Focus event jika tidak berasal dari 'Hidden'.
    // Ini menghentikan spam log saat Anda meminimize/restore aplikasi secara normal.
  }

  Future<void> _syncTaskbarOnVisible() async {
    // [V18.8 SOTA] THE DEBOUNCE GUARD (Anti-Spam)
    // OS Windows sering menembakkan event Restore & Focus bersamaan (<100ms).
    final now = DateTime.now();
    if (_lastSyncRequestTime != null &&
        now.difference(_lastSyncRequestTime!).inMilliseconds < 500) {
      return; // Batalkan eksekusi ganda dalam 500ms
    }
    _lastSyncRequestTime = now;

    // [V19.2 SOTA] THE STABILITY DELAY
    // Berikan jeda bagi Windows Desktop Window Manager (DWM) untuk mendaftarkan ulang
    // HWND di Taskbar SEBELUM kita menyuntikkan Thumbnail Toolbar.
    // [V19.3] Ditingkatkan menjadi 600ms untuk stabilitas ekstra.
    await Future.delayed(const Duration(milliseconds: 600));

    // [V19.3 SOTA] THE READINESS WAIT
    // Jika sistem belum siap (misal: baru start langsung di-hide), kita tunggu
    // hingga timer inisialisasi selesai daripada membatalkan sinkronisasi.
    if (!_isTaskbarReady) {
      debugPrint(
        '[WindowsTaskbar] System not ready yet. Waiting for stabilization...',
      );
      int retryCount = 0;
      while (!_isTaskbarReady && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retryCount++;
      }
      if (!_isTaskbarReady) return; // Menyerah setelah 5 detik
    }

    debugPrint(
      '[WindowsTaskbar] Window became visible. Re-syncing controls (Forced).',
    );

    // We use the last known playing state to restore the buttons.
    // If it was null, we default to false.
    final wasPlaying = _lastTaskbarPlayingState ?? false;

    // Reset the internal cache to force the native SetThumbnailToolbar call
    _lastTaskbarPlayingState = null;

    // [V18.8 SOTA] THE FORCE OVERRIDE
    // Kita HARUS memaksa update agar menembus guard visibilitas yang tidak stabil
    // saat window sedang dalam fase transisi animasi restore.
    await _updateTaskbarThumbnail(wasPlaying, force: true);
  }

  Future<void> _updateTaskbarThumbnail(
    bool isPlaying, {
    bool force = false,
  }) async {
    if (!Platform.isWindows) return;

    // 1. [V17.9] Check Readiness Guard
    if (!_isTaskbarReady) return;

    // 2. [V18.1] Check Visibility Guard
    // [V18.4] Buka pengecekan jika force=true (saat baru saja windowManager.show())
    if (!force && !(await windowManager.isVisible())) return;

    // 3. CEGAH UPDATE BERULANG Taskbar (Bypass if forced)
    if (!force && _lastTaskbarPlayingState == isPlaying) return;
    _lastTaskbarPlayingState = isPlaying;

    try {
      // [V19.3 SOTA] THE NUKE STRATEGY
      // Jika dipaksa (restored dari hidden), hapus toolbar lama terlebih dahulu
      // untuk membersihkan 'Ghost State' di memori Windows.
      if (force) {
        await WindowsTaskbar.resetThumbnailToolbar();
      }

      await WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/previous.ico'),
          'Previous',
          () => _onPrevious?.call(),
        ),
        ThumbnailToolbarButton(
          isPlaying
              ? ThumbnailToolbarAssetIcon('assets/icons/pause.ico')
              : ThumbnailToolbarAssetIcon('assets/icons/play.ico'),
          isPlaying ? 'Pause' : 'Play',
          () => isPlaying ? _onPause?.call() : _onPlay?.call(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/icons/next.ico'),
          'Next',
          () => _onNext?.call(),
        ),
      ]);
    } catch (e) {
      // [V17.9 SOTA] Silent Fail for non-critical native UI
      debugPrint('Taskbar update suppressed: $e');
    }
  }

  Future<void> dispose() async {
    _readinessTimer?.cancel();
    windowManager.removeListener(this);

    try {
      if (Platform.isWindows) {
        await WindowsTaskbar.resetThumbnailToolbar();
      }
    } catch (e) {
      debugPrint("Taskbar reset error: $e");
    }
  }
}
