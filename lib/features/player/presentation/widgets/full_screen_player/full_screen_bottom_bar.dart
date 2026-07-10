import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/widgets/play_pause_button.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/reusable_seek_slider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
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
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artist ?? 'Artist',
                              style: const TextStyle(
                                color: Colors.white70,
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
                          color: Colors.white70,
                          tooltip: 'Exit',
                          onTap: () => Navigator.pop(context),
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
      height: 32, // SOTA V3.4: Augmented hit-test area
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
          color: s.isShuffleEnabled ? colorScheme.primary : Colors.white70,
          onTap: n.toggleShuffle,
        ),
        ReusableHoverIconButton(
          tooltip: 'Previous',
          icon: UIcons.regular.step_backward,
          iconSize: 32,
          color: Colors.white,
          isDisabled: s.currentIndex <= 0 && s.loopMode == LoopMode.off,
          onTap: n.skipToPrevious,
        ),
        PlayPauseButton(
          isPlaying: s.isPlaying,
          isLoading: s.isLoading,
          size: PlayPauseSize.large,
          color: Colors.white,
          onTap: n.togglePlayPause,
        ),
        ReusableHoverIconButton(
          tooltip: 'Next',
          icon: UIcons.regular.step_forward,
          iconSize: 32,
          color: Colors.white,
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
          icon: s.loopMode == LoopMode.one ? UIcons.regular.arrows_repeat_1 : UIcons.regular.arrows_repeat,
          iconSize: 20,
          color: s.loopMode != LoopMode.off ? colorScheme.primary : Colors.white70,
          onTap: n.cycleLoopMode,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN VOLUME SLIDER (dengan toggle Mute)
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
            color: Colors.white70,
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
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
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
              style: const TextStyle(
                color: Colors.white70,
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
  /// context diperlukan untuk memanggil AudioSettingsSheet.show() yang
  /// membutuhkan BuildContext dari luar Consumer.
  final BuildContext context;
  const FullScreenUtilityButtons({super.key, required this.context});

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    return Row(
      children: [
        ReusableHoverIconButton(
          icon: UIcons.regular.microphone,
          iconSize: 20,
          color: Colors.white70,
          tooltip: 'Lyrics',
          onTap: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
        ),
        ReusableHoverIconButton(
          icon: UIcons.regular.settings_sliders,
          iconSize: 20,
          color: Colors.white70,
          tooltip: 'Audio Settings',
          // [DRY PRINCIPLE] Panggil AudioSettingsSheet.show() yang sudah
          // decoupled dan reusable – tidak ada duplikasi slider Speed/Pitch.
          onTap: () => AudioSettingsSheet.show(context),
        ),
      ],
    );
  }
}
