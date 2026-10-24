import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resonance/features/player/application/providers/audio_provider.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/data/models/player_enums.dart';

class AudioCoreControls extends ConsumerWidget {
  final bool isDesktop;

  const AudioCoreControls({super.key, this.isDesktop = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      isPlaying,
      isLoading,
      isShuffleEnabled,
      loopMode,
      isPrevDisabled,
      isNextDisabled,
    ) = ref.watch(
      audioProvider.select((s) => (
        s.isPlaying,
        s.isLoading,
        s.isShuffleEnabled,
        s.loopMode,
        s.currentIndex <= 0 && s.loopMode == LoopMode.off,
        s.currentIndex >= s.queue.length - 1 && s.loopMode == LoopMode.off,
      )),
    );
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
                color: isShuffleEnabled
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                iconSize: 18,
                onTap: () => audioNotifier.toggleShuffle(),
              ),
              ReusableHoverIconButton(
                tooltip: 'Previous',
                icon: UIcons.regular.step_backward,
                iconSize: 18,
                isDisabled: isPrevDisabled,
                onTap: () => audioNotifier.skipToPrevious(),
              ),
              PlayPauseButton(
                isPlaying: isPlaying,
                isLoading: isLoading,
                size: PlayPauseSize.medium,
                onTap: () => audioNotifier.togglePlayPause(),
              ),
              ReusableHoverIconButton(
                tooltip: 'Next',
                icon: UIcons.regular.step_forward,
                iconSize: 18,
                isDisabled: isNextDisabled,
                onTap: () => audioNotifier.skipToNext(),
              ),
              ReusableHoverIconButton(
                tooltip: loopMode == LoopMode.off
                    ? 'Repeat Off'
                    : loopMode == LoopMode.one
                        ? 'Repeat One'
                        : 'Repeat All',
                icon: loopMode == LoopMode.one
                    ? UIcons.regular.arrows_repeat_1
                    : UIcons.regular.arrows_repeat,
                color: loopMode == LoopMode.off
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
            isPlaying: isPlaying,
            isLoading: isLoading,
            size: PlayPauseSize.small,
            onTap: () => audioNotifier.togglePlayPause(),
          ),
          const SizedBox(width: 4),
          ReusableHoverIconButton(
            tooltip: 'Next',
            icon: UIcons.regular.step_forward,
            iconSize: 18,
            isDisabled: isNextDisabled,
            onTap: () => audioNotifier.skipToNext(),
          ),
        ],
      );
    }
  }
}
