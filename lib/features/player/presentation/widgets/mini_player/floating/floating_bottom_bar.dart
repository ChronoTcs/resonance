import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class FloatingBottomBar extends ConsumerWidget {
  const FloatingBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioNotifier = ref.read(audioProvider.notifier);
    final track = ref.watch(currentTrackProvider);

    if (track == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
    final isLoading = ref.watch(audioProvider.select((s) => s.isLoading));
    final isPrevDisabled = ref.watch(audioProvider.select((s) => s.currentIndex <= 0));
    final isNextDisabled = ref.watch(audioProvider.select((s) => s.nextTrack == null));
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _FloatingProgressBar(),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                // Song Info (Marquee Title)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 18,
                        child: ResonanceMarqueeText(
                          text: track.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        track.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Navigation Controls (Standardized)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReusableHoverIconButton(
                      icon: UIcons.regular.step_backward,
                      onTap: audioNotifier.skipToPrevious,
                      tooltip: 'Previous',
                      iconSize: 18,
                      padding: 4,
                      color: theme.colorScheme.onSurface,
                      isDisabled: isPrevDisabled,
                    ),
                    const SizedBox(width: 4),
                    PlayPauseButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      onTap: audioNotifier.togglePlayPause,
                      size: PlayPauseSize.small,
                    ),
                    const SizedBox(width: 4),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.step_forward,
                      onTap: audioNotifier.skipToNext,
                      tooltip: 'Next',
                      iconSize: 18,
                      padding: 4,
                      color: theme.colorScheme.onSurface,
                      isDisabled: isNextDisabled,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingProgressBar extends ConsumerWidget {
  const _FloatingProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(audioProvider.select((s) => s.position));
    final dur = ref.watch(audioProvider.select((s) => s.duration));
    return RepaintBoundary(
      child: ReusableSeekSlider(
        value: pos.inMilliseconds.toDouble(),
        max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 0.0,
        onChanged: (_) {},
        onChangeEnd: (v) => ref.read(audioProvider.notifier).seek(Duration(milliseconds: v.toInt())),
        trackHeight: 2,
        height: 4,
        thumbRadius: 0,
      ),
    );
  }
}
