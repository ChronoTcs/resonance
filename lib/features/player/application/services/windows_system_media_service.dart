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
  DateTime? _lastSyncRequestTime;
  bool _wasHiddenToTray = false;

  Future<void> updateMetadata(
    MediaItem? track,
    bool isPlaying, {
    String? overrideThumbnailUrl,
    bool force = false,
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
      if (!force &&
          _lastSMTCTitle == track.title &&
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
        if (await windowManager.isVisible()) {
          await WindowsTaskbar.setProgress(
            position.inMilliseconds,
            duration.inMilliseconds,
          );
        }
      }
    } catch (e) {
      if (e is! PlatformException) {
        debugPrint("Taskbar timeline update error: $e");
      }
    }
  }

  // WINDOW LIFECYCLE HANDLERS
  void onWindowHide() {
    // Windows destroys the Taskbar Button when the window is hidden (Close to Tray)
    _wasHiddenToTray = true;
  }

  @override
  void onWindowMinimize() {
    // Windows retains the Taskbar Button when minimized.
    // Set to false to prevent redundant re-syncing.
    _wasHiddenToTray = false;
  }

  @override
  void onWindowRestore() {
    // Force sync only if the window is restored from 'Hidden' mode
    if (_wasHiddenToTray) {
      _syncTaskbarOnVisible();
      _wasHiddenToTray = false;
    }
  }

  @override
  void onWindowFocus() {
    // Ignore Focus event if not restored from 'Hidden'.
    // Stops log spam during normal minimize/restore events.
  }

  Future<void> _syncTaskbarOnVisible() async {
    // Windows OS often fires Restore & Focus events concurrently (<100ms).
    final now = DateTime.now();
    if (_lastSyncRequestTime != null &&
        now.difference(_lastSyncRequestTime!).inMilliseconds < 500) {
      return; // Prevent duplicate execution within 500ms
    }
    _lastSyncRequestTime = now;

    // Give Windows Desktop Window Manager (DWM) time to re-register
    // HWND in the Taskbar BEFORE we inject the Thumbnail Toolbar.
    await Future.delayed(const Duration(milliseconds: 600));

    // If the system is not ready yet (e.g. hidden right after start), wait
    // until the initialization timer finishes instead of canceling sync.
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

    // Force update to bypass visibility guards during window restore transition.
    await _updateTaskbarThumbnail(wasPlaying, force: true);
  }

  Future<void> _updateTaskbarThumbnail(
    bool isPlaying, {
    bool force = false,
  }) async {
    if (!Platform.isWindows) return;

    if (!_isTaskbarReady) return;

    if (!force && !(await windowManager.isVisible())) return;

    // 3. Prevent redundant taskbar updates (Bypass if forced)
    if (!force && _lastTaskbarPlayingState == isPlaying) return;
    _lastTaskbarPlayingState = isPlaying;

    try {
      // If forced (restored from hidden), clear the previous toolbar first
      // to clean up 'Ghost State' in Windows memory.
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
