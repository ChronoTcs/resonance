import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/play_pause_button.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/data/models/player_enums.dart';

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
                icon: UIcons.regular.shuffle,
                color: audioState.isShuffleEnabled
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                iconSize: 18,
                onTap: () => audioNotifier.toggleShuffle(),
              ),
              ReusableHoverIconButton(
                tooltip: 'Previous',
                icon: UIcons.regular.step_backward,
                iconSize: 18,
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
                icon: UIcons.regular.step_forward,
                iconSize: 18,
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
                    ? UIcons.regular.arrows_repeat_1
                    : UIcons.regular.arrows_repeat,
                color: audioState.loopMode == LoopMode.off
                    ? Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)
                    : Theme.of(context).primaryColor,
                iconSize: 18,
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
            size: PlayPauseSize.small,
            onTap: () => audioNotifier.togglePlayPause(),
          ),
          ReusableHoverIconButton(
            tooltip: 'Next',
            icon: UIcons.regular.step_forward,
            iconSize: 18,
            isDisabled: audioState.currentIndex >= audioState.queue.length - 1 &&
                audioState.loopMode == LoopMode.off,
            onTap: () => audioNotifier.skipToNext(),
          ),
        ],
      );
    }
  }
}
