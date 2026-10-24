import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/equalizer_sheet.dart';

class AudioSettingsSheet extends StatelessWidget {
  const AudioSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const AudioSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingSheetShell(
      maxWidth: 440,
      title: 'Audio Settings',
      onClose: () => Navigator.pop(context),
      children: [
        const _AudioSlidersBento(),
        const SizedBox(height: 12),
        _EqualizerButton(
          onTap: () {
            Navigator.pop(context);
            EqualizerSheet.show(context);
          },
        ),
      ],
    );
  }
}

class _AudioSlidersBento extends StatelessWidget {
  const _AudioSlidersBento();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
        ),
      ),
      child: Column(
        children: [
          const _VolumeSlider(),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
          ),
          const SizedBox(height: 12),
          const _PlaybackSpeedSlider(),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
          ),
          const SizedBox(height: 12),
          const _PitchSlider(),
        ],
      ),
    );
  }
}

class _VolumeSlider extends ConsumerStatefulWidget {
  const _VolumeSlider();

  @override
  ConsumerState<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<_VolumeSlider> {
  double _prevVolume = 100.0;

  void _toggleMute(double currentVolume) {
    if (currentVolume > 0) {
      _prevVolume = currentVolume;
      ref.read(audioProvider.notifier).setVolume(0);
    } else {
      ref.read(audioProvider.notifier).setVolume(_prevVolume > 0 ? _prevVolume : 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final volume = ref.watch(audioProvider.select((s) => s.volume));

    final IconData volumeIcon = volume == 0
        ? UIcons.regular.volume_off
        : volume < 50
            ? UIcons.regular.volume_down
            : UIcons.regular.volume;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => _toggleMute(volume),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      volumeIcon,
                      size: 15,
                      color: volume == 0
                          ? colorScheme.error.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Volume',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => _toggleMute(volume),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: volume == 0
                      ? colorScheme.error.withValues(alpha: 0.12)
                      : colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${volume.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: volume == 0 ? colorScheme.error : colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '0%',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Slider(
                    value: volume.clamp(0.0, 100.0),
                    min: 0.0,
                    max: 100.0,
                    activeColor: colorScheme.primary,
                    onChanged: (val) {
                      if (val > 0) _prevVolume = val;
                      ref.read(audioProvider.notifier).setVolume(val);
                    },
                  ),
                ),
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaybackSpeedSlider extends ConsumerWidget {
  const _PlaybackSpeedSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final speed = ref.watch(audioProvider.select((s) => s.speed));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Playback Speed',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${speed.toStringAsFixed(1)}x',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '0.5x',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Slider(
                    value: speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: colorScheme.primary,
                    onChanged: (val) => ref
                        .read(audioProvider.notifier)
                        .setSpeed(val),
                  ),
                ),
              ),
            ),
            Text(
              '2.0x',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PitchSlider extends ConsumerWidget {
  const _PitchSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final pitch = ref.watch(audioProvider.select((s) => s.pitch));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pitch',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${pitch > 0 ? '+' : ''}${pitch.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '-12',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Slider(
                    value: pitch,
                    min: -12.0,
                    max: 12.0,
                    divisions: 24,
                    activeColor: colorScheme.primary,
                    onChanged: (val) => ref
                        .read(audioProvider.notifier)
                        .setPitch(val),
                  ),
                ),
              ),
            ),
            Text(
              '+12',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EqualizerButton extends StatefulWidget {
  const _EqualizerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_EqualizerButton> createState() => _EqualizerButtonState();
}

class _EqualizerButtonState extends State<_EqualizerButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final baseBg = colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5);
    final hoverBg = colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.65 : 0.85);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered ? hoverBg : baseBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  UIcons.regular.settings_sliders,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equalizer Settings',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Custom 9-band frequency & presets',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                UIcons.regular.angle_small_right,
                size: 18,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

