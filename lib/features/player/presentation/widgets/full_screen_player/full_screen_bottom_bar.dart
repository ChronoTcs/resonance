import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/data/models/player_enums.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/shared/audio_settings_sheet.dart';

/// [FullScreenBottomBar]
/// Bar kontrol di bagian bawah layar fullscreen.
/// Berisi: Info Track (kiri) · Kontrol Playback (tengah) · Volume + Utility (kanan)
class FullScreenBottomBar extends StatelessWidget {
  final dynamic track;
  const FullScreenBottomBar({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const SizedBox(height: 8, child: FullScreenProgress()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                // LEFT: Track Info
                Expanded(
                  flex: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: MediaArtworkWidget(item: track),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artist ?? 'Artist',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // CENTER: Playback Controls
                const Expanded(
                  flex: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: FullScreenControls(),
                  ),
                ),

                // RIGHT: Utility Buttons + Volume + Exit
                Expanded(
                  flex: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FullScreenUtilityButtons(context: context),
                        const SizedBox(width: 8),
                        const FullScreenVolumeSlider(),
                        ReusableHoverIconButton(
                          icon: UIcons.regular.compress,
                          iconSize: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          tooltip: 'Exit',
                          onTap: () => Navigator.maybePop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN PROGRESS SEEK SLIDER
// ─────────────────────────────────────────────────────────────────────────────

class FullScreenProgress extends ConsumerWidget {
  const FullScreenProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioProvider);
    return SizedBox(
      height: 32,
      child: ReusableSeekSlider(
        value: s.position.inMilliseconds.toDouble(),
        max: s.duration.inMilliseconds.toDouble() > 0
            ? s.duration.inMilliseconds.toDouble()
            : 1.0,
        onChanged: (v) =>
            ref.read(audioProvider.notifier).seek(Duration(milliseconds: v.toInt())),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN PLAYBACK CONTROLS (Shuffle, Prev, Play/Pause, Next, Repeat)
// ─────────────────────────────────────────────────────────────────────────────

class FullScreenControls extends ConsumerWidget {
  const FullScreenControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioProvider);
    final n = ref.read(audioProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ReusableHoverIconButton(
          tooltip: 'Shuffle',
          icon: UIcons.regular.shuffle,
          iconSize: 20,
          color: s.isShuffleEnabled
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.7),
          onTap: n.toggleShuffle,
        ),
        ReusableHoverIconButton(
          tooltip: 'Previous',
          icon: UIcons.regular.step_backward,
          iconSize: 32,
          color: colorScheme.onSurface,
          isDisabled: s.currentIndex <= 0 && s.loopMode == LoopMode.off,
          onTap: n.skipToPrevious,
        ),
        PlayPauseButton(
          isPlaying: s.isPlaying,
          isLoading: s.isLoading,
          size: PlayPauseSize.large,
          color: colorScheme.onSurface,
          onTap: n.togglePlayPause,
        ),
        ReusableHoverIconButton(
          tooltip: 'Next',
          icon: UIcons.regular.step_forward,
          iconSize: 32,
          color: colorScheme.onSurface,
          isDisabled:
              s.currentIndex >= s.queue.length - 1 && s.loopMode == LoopMode.off,
          onTap: n.skipToNext,
        ),
        ReusableHoverIconButton(
          tooltip: s.loopMode == LoopMode.one
              ? 'Repeat One'
              : s.loopMode == LoopMode.all
                  ? 'Repeat All'
                  : 'Repeat Off',
          icon: s.loopMode == LoopMode.one
              ? UIcons.regular.arrows_repeat_1
              : UIcons.regular.arrows_repeat,
          iconSize: 20,
          color: s.loopMode != LoopMode.off
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.7),
          onTap: n.cycleLoopMode,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN VOLUME SLIDER (with toggle Mute)
// ─────────────────────────────────────────────────────────────────────────────

class FullScreenVolumeSlider extends ConsumerStatefulWidget {
  const FullScreenVolumeSlider({super.key});

  @override
  ConsumerState<FullScreenVolumeSlider> createState() =>
      _FullScreenVolumeSliderState();
}

class _FullScreenVolumeSliderState extends ConsumerState<FullScreenVolumeSlider> {
  double _prevVolume = 50.0;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(audioProvider.select((s) => s.volume));
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ReusableHoverIconButton(
            padding: 0,
            icon: v == 0
                ? UIcons.regular.volume_off
                : v < 50
                    ? UIcons.regular.volume_down
                    : UIcons.regular.volume,
            iconSize: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            tooltip: 'Mute/Unmute',
            onTap: () {
              if (v > 0) {
                _prevVolume = v;
                ref.read(audioProvider.notifier).setVolume(0);
              } else {
                ref
                    .read(audioProvider.notifier)
                    .setVolume(_prevVolume > 0 ? _prevVolume : 50);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: colorScheme.onSurface,
                inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.24),
                thumbColor: colorScheme.onSurface,
              ),
              child: Slider(
                value: v,
                min: 0,
                max: 100,
                onChanged: (val) {
                  ref.read(audioProvider.notifier).setVolume(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${v.toInt()}%',
              softWrap: false,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN UTILITY BUTTONS (Lyrics, Audio Settings)
// ─────────────────────────────────────────────────────────────────────────────

class FullScreenUtilityButtons extends ConsumerWidget {
  /// context is required to show the AudioSettingsSheet,
  /// needing a BuildContext from outside the Consumer.
  final BuildContext context;
  const FullScreenUtilityButtons({super.key, required this.context});

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final colorScheme = Theme.of(buildContext).colorScheme;

    return Row(
      children: [
        ReusableHoverIconButton(
          icon: UIcons.regular.microphone,
          iconSize: 20,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
          tooltip: 'Lyrics',
          onTap: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
        ),
        ReusableHoverIconButton(
          icon: UIcons.regular.settings_sliders,
          iconSize: 20,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
          tooltip: 'Audio Settings',
          // Call AudioSettingsSheet.show() which is decoupled and reusable.
          onTap: () => AudioSettingsSheet.show(context),
        ),
      ],
    );
  }
}
