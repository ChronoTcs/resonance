import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/audio_docked_player.dart';

class DockedMiniPlayer extends ConsumerWidget {
  const DockedMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final currentTrack = audioState.currentTrack;

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    return const AudioDockedPlayer();
  }
}
