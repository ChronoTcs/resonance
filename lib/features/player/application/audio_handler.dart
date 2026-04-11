import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResonanceAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final Player player;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;

  ResonanceAudioHandler(this.player) {
    _init();
  }

  void _init() {
    player.stream.playing.listen((playing) {
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
        processingState: AudioProcessingState.ready,
      ));
    });

    player.stream.position.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    player.stream.duration.listen((duration) {
      if (mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });

    player.stream.buffer.listen((buffer) {
      playbackState.add(playbackState.value.copyWith(
        bufferedPosition: buffer,
      ));
    });

    player.stream.completed.listen((completed) {
      if (completed) {
        playbackState.add(playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.completed,
        ));
      }
    });

    player.stream.buffering.listen((buffering) {
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

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() => player.stop();

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
