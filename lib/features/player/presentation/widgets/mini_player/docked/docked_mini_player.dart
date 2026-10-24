import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/audio_docked_player.dart';

class DockedMiniPlayer extends ConsumerWidget {
  const DockedMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(audioProvider.select((s) => s.currentTrack != null));

    if (!hasTrack) {
      return const SizedBox.shrink();
    }

    return const RepaintBoundary(
      child: AudioDockedPlayer(),
    );
  }
}
