import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/inputs/resonance_switch.dart';
import '../../application/providers/equalizer_controller.dart';

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const EqualizerSheet(),
    );
  }

  static const List<String> _bandLabels = [
    '62 Hz',
    '125 Hz',
    '250 Hz',
    '500 Hz',
    '1 kHz',
    '2 kHz',
    '4 kHz',
    '8 kHz',
    '16 kHz',
  ];

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  bool _isPresetHovered = false;
  bool _isLinkHovered = false;
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    final eqState = ref.watch(equalizerControllerProvider);
    final eqNotifier = ref.read(equalizerControllerProvider.notifier);

    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark
        ? colorScheme.surface.withValues(alpha: 0.90)
        : colorScheme.surface.withValues(alpha: 0.95);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () {},
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 500,
                      padding: const EdgeInsets.only(
                        top: 12.0,
                        left: 28.0,
                        right: 28.0,
                        bottom: 16.0,
                      ),
                      decoration: BoxDecoration(
                        color: sheetBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pill drag handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: onSurfaceVariant.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Equaliser',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  Text(
                    eqState.isEnabled ? 'On' : 'Off',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: eqState.isEnabled
                          ? colorScheme.primary
                          : onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ResonanceSwitch(
                    value: eqState.isEnabled,
                    onChanged: (val) {
                      eqNotifier.toggleEqualizer(val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Preset Row
          Row(
            children: [
              const Text(
                'Preset',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isPresetHovered = true),
                onExit: (_) => setState(() => _isPresetHovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isPresetHovered
                        ? colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.8,
                          )
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isPresetHovered
                          ? colorScheme.outline.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: eqState.preset,
                      dropdownColor: colorScheme.surfaceContainerHighest,
                      icon: Icon(
                        UIcons.regular.angle_small_down,
                        color: onSurfaceVariant,
                        size: 20,
                      ),
                      items: ['Flat', 'Bass Boost', 'Vocal', 'Custom'].map((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: eqState.preset == value
                                  ? colorScheme.primary
                                  : onSurface,
                              fontSize: 14,
                              fontWeight: eqState.preset == value
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null && newValue != 'Custom') {
                          eqNotifier.setEqualizerPreset(newValue);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Sliders Area
          Expanded(
            child: Row(
              children: [
                _TickScaleColumn(onSurfaceVariant: onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: SilkySingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(9, (index) {
                        return _EqualizerBandSlider(
                          label: EqualizerSheet._bandLabels[index],
                          value: eqState.bands[index],
                          isEnabled: eqState.isEnabled,
                          onChanged: (val) {
                            eqNotifier.setEqualizerBand(index, val);
                          },
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Control Row
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Checkbox + Label Row (Interactive & Hoverable)
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isLinkHovered = true),
                  onExit: (_) => setState(() => _isLinkHovered = false),
                  child: GestureDetector(
                    onTap: () =>
                        eqNotifier.toggleLinkSliders(!eqState.linkSliders),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isLinkHovered
                            ? colorScheme.onSurface.withValues(alpha: 0.06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: eqState.linkSliders,
                              activeColor: colorScheme.primary,
                              checkColor: colorScheme.onPrimary,
                              side: BorderSide(color: onSurfaceVariant),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  eqNotifier.toggleLinkSliders(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Move nearby sliders together',
                              style: TextStyle(
                                color: _isLinkHovered
                                    ? onSurface
                                    : onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: _isLinkHovered
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Close Button (Interactive & Hoverable)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isCloseHovered = true),
                onExit: (_) => setState(() => _isCloseHovered = false),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _isCloseHovered
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: _isCloseHovered
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EqualizerBandSlider extends StatelessWidget {
  const _EqualizerBandSlider({
    required this.label,
    required this.value,
    required this.isEnabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool isEnabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Tick marks
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    5,
                    (_) => Container(
                      width: 24,
                      height: 1,
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                // Slider
                RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor:
                          colorScheme.surfaceContainerHighest,
                      thumbColor: colorScheme.primary,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                        elevation: 2,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: value,
                      min: -12.0,
                      max: 12.0,
                      onChanged: isEnabled ? onChanged : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TickScaleColumn extends StatelessWidget {
  const _TickScaleColumn({required this.onSurfaceVariant});

  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('+12 dB', style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
        Text(' +6 dB', style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
        Text('  0 dB', style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
        Text(' -6 dB', style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
        Text('-12 dB', style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 20),
      ],
    );
  }
}
