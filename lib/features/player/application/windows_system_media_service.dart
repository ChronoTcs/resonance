import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:window_manager/window_manager.dart';
import '../../library/data/models/media_item.dart';

final windowsSystemMediaServiceProvider = Provider<WindowsSystemMediaService>((ref) {
  return WindowsSystemMediaService();
});

class WindowsSystemMediaService {
  SMTCWindows? _smtc;
  StreamSubscription? _buttonSub;
  
  VoidCallback? _onPlay;
  VoidCallback? _onPause;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;
  VoidCallback? _onStop;

  WindowsSystemMediaService();

  Future<void> initialize({
    VoidCallback? onPlay,
    VoidCallback? onPause,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    VoidCallback? onStop,
  }) async {
    if (!Platform.isWindows) return;
    if (_smtc != null) {
      setCallbacks(
        onPlay: onPlay,
        onPause: onPause,
        onNext: onNext,
        onPrevious: onPrevious,
        onStop: onStop,
      );
      return;
    }

    _onPlay = onPlay;
    _onPause = onPause;
    _onNext = onNext;
    _onPrevious = onPrevious;
    _onStop = onStop;

    try {
      _smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );

      _buttonSub = _smtc?.buttonPressStream.listen((event) {
        try {
          switch (event) {
            case PressedButton.play: _onPlay?.call(); break;
            case PressedButton.pause: _onPause?.call(); break;
            case PressedButton.next: _onNext?.call(); break;
            case PressedButton.previous: _onPrevious?.call(); break;
            case PressedButton.stop: _onStop?.call(); break;
            default: break;
          }
        } catch (e) {
          debugPrint("SMTC button press handling error: $e");
        }
      });
    } catch (e) {
      debugPrint("SMTC initialization error: $e");
    }
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
    _onStop = onStop;
    
    // Update taskbar toolbar after callbacks change
    if (_smtc != null) {
      // Re-trigger thumbnail update with current status if possible, 
      // but status might not be available here. 
      // Individual notifiers should call updatePlaybackStatus.
    }
  }

  Future<void> updateMetadata(MediaItem? track, bool isPlaying) async {
    if (!Platform.isWindows) return;
    
    try {
      if (track == null) {
        await _smtc?.setPlaybackStatus(PlaybackStatus.Stopped);
        if (Platform.isWindows) {
          await windowManager.setTitle('Resonance');
        }
        return;
      }

      if (Platform.isWindows) {
        await windowManager.setTitle('${track.title} - ${track.artist ?? 'Unknown Artist'} | Resonance');
      }

      await _smtc?.updateMetadata(
        MusicMetadata(
          title: track.title,
          artist: track.artist ?? 'Unknown Artist',
          album: track.album ?? 'Unknown Album',
          thumbnail: track.thumbnailUrl != null 
              ? (track.thumbnailUrl!.startsWith('http') 
                  ? track.thumbnailUrl 
                  : Uri.file(track.thumbnailUrl!).toString())
              : null,
        ),
      );

      await updatePlaybackStatus(isPlaying);
    } catch (e) {
      debugPrint("SMTC metadata update error: $e");
    }
  }

  Future<void> updatePlaybackStatus(bool isPlaying) async {
    if (!Platform.isWindows) return;
    
    try {
      await _smtc?.setPlaybackStatus(
        isPlaying ? PlaybackStatus.Playing : PlaybackStatus.Paused,
      );
      await _updateTaskbarThumbnail(isPlaying);
    } catch (e) {
      debugPrint("SMTC playback status update error: $e");
    }
  }

  Future<void> updateTimeline(Duration position, Duration duration) async {
    if (!Platform.isWindows) return;

    try {
      await _smtc?.setTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: duration.inMilliseconds,
          positionMs: position.inMilliseconds,
        ),
      );
      
      if (duration.inMilliseconds > 0) {
        await WindowsTaskbar.setProgress(
          position.inMilliseconds,
          duration.inMilliseconds,
        );
      }
    } catch (e) {
      debugPrint("SMTC/Taskbar timeline update error: $e");
    }
  }

  Future<void> _updateTaskbarThumbnail(bool isPlaying) async {
    if (!Platform.isWindows) return;
    try {
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
      debugPrint('Taskbar thumbnail error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _buttonSub?.cancel();
      _buttonSub = null;
      await _smtc?.dispose();
    } catch (e) {
      debugPrint("SMTC dispose error: $e");
    }
    
    try {
      if (Platform.isWindows) {
        await WindowsTaskbar.resetThumbnailToolbar();
      }
    } catch (e) {
      debugPrint("Taskbar reset error: $e");
    }
  }
}
