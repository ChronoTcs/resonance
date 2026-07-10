import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/video_player_notifier.dart' as v;
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/audio_docked_player.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/video_docked_player.dart';

class DockedMiniPlayer extends ConsumerWidget {
  const DockedMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(v.videoPlayerProvider);
    final audioState = ref.watch(audioProvider);
    final isVideo = videoState.currentVideo != null;
    final currentTrack = audioState.currentTrack;

    if (isVideo) {
      return const VideoDockedPlayer();
    }

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    return const AudioDockedPlayer();
  }
}
