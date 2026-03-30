import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import '../../../features/library/data/models/media_item.dart';

final windowsSystemMediaServiceProvider = Provider<WindowsSystemMediaService>((ref) {
  return WindowsSystemMediaService();
});

class WindowsSystemMediaService {
  SMTCWindows? _smtc;
  
  // Callbacks
  VoidCallback? _onPlay;
  VoidCallback? _onPause;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;
  VoidCallback? _onStop;

  WindowsSystemMediaService();

  Future<void> initialize({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required VoidCallback onStop,
  }) async {
    if (!Platform.isWindows) return;

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

      _smtc?.buttonPressStream.listen((event) {
        switch (event) {
          case PressedButton.play: _onPlay?.call(); break;
          case PressedButton.pause: _onPause?.call(); break;
          case PressedButton.next: _onNext?.call(); break;
          case PressedButton.previous: _onPrevious?.call(); break;
          case PressedButton.stop: _onStop?.call(); break;
          default: break;
        }
      });
    } catch (e) {
      debugPrint("SMTC initialization error: $e");
    }
  }

  void updateMetadata(MediaItem? track, bool isPlaying) {
    if (!Platform.isWindows || _smtc == null) return;

    if (track == null) {
      _smtc?.setPlaybackStatus(PlaybackStatus.Stopped);
      return;
    }

    _smtc?.updateMetadata(
      MusicMetadata(
        title: track.title,
        artist: track.artist ?? 'Unknown Artist',
        album: track.album ?? 'Unknown Album',
        thumbnail: track.thumbnailUrl,
      ),
    );

    updatePlaybackStatus(isPlaying);
  }

  void updatePlaybackStatus(bool isPlaying) {
    if (!Platform.isWindows) return;
    
    _smtc?.setPlaybackStatus(
      isPlaying ? PlaybackStatus.Playing : PlaybackStatus.Paused,
    );
    _updateTaskbarThumbnail(isPlaying);
  }

  void updateTimeline(Duration position, Duration duration) {
    if (!Platform.isWindows || _smtc == null) return;

    _smtc?.setTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: duration.inMilliseconds,
        positionMs: position.inMilliseconds,
      ),
    );
    
    if (duration.inMilliseconds > 0) {
      WindowsTaskbar.setProgress(
        position.inMilliseconds,
        duration.inMilliseconds,
      );
    }
  }

  void _updateTaskbarThumbnail(bool isPlaying) {
    if (!Platform.isWindows) return;
    try {
      WindowsTaskbar.setThumbnailToolbar([
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

  void dispose() {
    _smtc?.dispose();
    if (Platform.isWindows) {
      WindowsTaskbar.resetThumbnailToolbar();
    }
  }
}
