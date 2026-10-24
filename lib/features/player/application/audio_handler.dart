import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResonanceAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final Player player;
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onStop;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;

  ResonanceAudioHandler(this.player) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: AudioProcessingState.idle,
    ));
    _init();
  }

  void _init() {
    player.stream.playing.listen((playing) {
      final currentProcessing = playbackState.value.processingState;
      if (!playing && currentProcessing == AudioProcessingState.idle) {
        return;
      }
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        updatePosition: player.state.position,
        speed: player.state.rate,
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: playing
            ? AudioProcessingState.ready
            : (currentProcessing == AudioProcessingState.idle
                ? AudioProcessingState.idle
                : AudioProcessingState.ready),
      ));
    });

    // Emit position update on track change to sync OS MediaSession
    mediaItem.listen((item) {
      if (item != null) {
        playbackState.add(playbackState.value.copyWith(
          updatePosition: player.state.position,
        ));
      }
    });

    player.stream.duration.listen((duration) {
      // duration is NOT sent to SMTC by audio_service_win. On Windows,
      // emitting mediaItem.add() here creates a stale setMediaItem(prevTrack) call
      // during gapless transitions that races with the correct thread.
      if (Platform.isWindows) return;
      if (duration > Duration.zero && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });

    player.stream.buffer.listen((buffer) {
      if (playbackState.value.processingState == AudioProcessingState.idle) {
        return;
      }
      playbackState.add(playbackState.value.copyWith(
        bufferedPosition: buffer,
      ));
    });

    player.stream.completed.listen((completed) {
      if (completed) {
        // Transition to buffering rather than completed to protect Android Foreground Service
        // while the upcoming queue track URL resolves asynchronously in background.
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.buffering,
        ));
      }
    });

    player.stream.buffering.listen((buffering) {
      if (playbackState.value.processingState == AudioProcessingState.idle) {
        return;
      }
      if (buffering) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.buffering,
        ));
      } else {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
        ));
      }
    });
  }

  void notifyQueueCompleted() {
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.completed,
    ));
  }

  @override
  Future<void> onNotificationDeleted() async {
    // When notification is swiped or dismissed on Android, pause playback
    // instead of stopping and unloading libmpv media via player.stop().
    await pause();
  }

  @override
  Future<void> play() async {
    if (onPlay != null) {
      onPlay!();
    } else {
      await player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (onPause != null) {
      onPause!();
    } else {
      await player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
    await player.seek(position);
  }

  @override
  Future<void> stop() async {
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    if (onStop != null) {
      onStop!();
    } else {
      await player.stop();
    }
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }
}

final audioHandlerProvider = Provider<ResonanceAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main.dart');
});
