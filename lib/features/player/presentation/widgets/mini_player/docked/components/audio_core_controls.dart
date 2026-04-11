import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance_app/core/widgets/play_pause_button.dart';
import 'package:resonance_app/features/player/application/providers/audio_provider.dart';

import 'package:resonance_app/features/player/data/models/player_enums.dart';

class AudioCoreControls extends ConsumerWidget {
  final bool isDesktop;

  const AudioCoreControls({super.key, this.isDesktop = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    if (isDesktop) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ReusableHoverIconButton(
                tooltip: 'Shuffle',
                icon: Icons.shuffle,
                color: audioState.isShuffleEnabled
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                iconSize: 20,
                onTap: () => audioNotifier.toggleShuffle(),
              ),
              ReusableHoverIconButton(
                tooltip: 'Previous',
                icon: Icons.skip_previous,
                iconSize: 24,
                isDisabled: audioState.currentIndex <= 0 &&
                    audioState.loopMode == LoopMode.off,
                onTap: () => audioNotifier.skipToPrevious(),
              ),
              PlayPauseButton(
                isPlaying: audioState.isPlaying,
                isLoading: audioState.isLoading,
                size: PlayPauseSize.medium,
                onTap: () => audioNotifier.togglePlayPause(),
              ),
              ReusableHoverIconButton(
                tooltip: 'Next',
                icon: Icons.skip_next,
                iconSize: 24,
                isDisabled: audioState.currentIndex >= audioState.queue.length - 1 &&
                    audioState.loopMode == LoopMode.off,
                onTap: () => audioNotifier.skipToNext(),
              ),
              ReusableHoverIconButton(
                tooltip: audioState.loopMode == LoopMode.off
                    ? 'Repeat Off'
                    : audioState.loopMode == LoopMode.one
                        ? 'Repeat One'
                        : 'Repeat All',
                icon: audioState.loopMode == LoopMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: audioState.loopMode == LoopMode.off
                    ? Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)
                    : Theme.of(context).primaryColor,
                iconSize: 20,
                isSelected: false,
                onTap: () => audioNotifier.cycleLoopMode(),
              ),
            ],
          ),
        ],
      );
    } else {
      // Mobile Small Controls
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayPauseButton(
            isPlaying: audioState.isPlaying,
            isLoading: audioState.isLoading,
            size: PlayPauseSize.medium,
            onTap: () => audioNotifier.togglePlayPause(),
          ),
          ReusableHoverIconButton(
            tooltip: 'Next',
            icon: Icons.skip_next,
            iconSize: 24,
            isDisabled: audioState.currentIndex >= audioState.queue.length - 1 &&
                audioState.loopMode == LoopMode.off,
            onTap: () => audioNotifier.skipToNext(),
          ),
        ],
      );
    }
  }
}
