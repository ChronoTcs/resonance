import 'package:flutter/material.dart';

/// Single vertical band slider with dynamic top dB badge and bottom frequency label.
class EqualizerBandSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool isEnabled;
  final ValueChanged<double> onChanged;

  const EqualizerBandSlider({
    super.key,
    required this.label,
    required this.value,
    required this.isEnabled,
    required this.onChanged,
  });

  String _formatDb(double val) {
    if (val.abs() < 0.05) return '0 dB';
    final sign = val > 0 ? '+' : '';
    final formatted = val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
    return '$sign$formatted dB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNonZero = value.abs() >= 0.05;

    final badgeBg = (isNonZero && isEnabled)
        ? colorScheme.primary.withValues(alpha: 0.15)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final badgeTextColor = !isEnabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : isNonZero
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Dynamic dB readout badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _formatDb(value),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isNonZero && isEnabled ? FontWeight.bold : FontWeight.w500,
              color: badgeTextColor,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. Vertical Slider with Center Detent
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background reference ticks (+12, +6, 0, -6, -12 dB)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TickMark(color: colorScheme.outline.withValues(alpha: 0.15), width: 14),
                    _TickMark(color: colorScheme.outline.withValues(alpha: 0.15), width: 14),
                    // Center 0 dB tick is slightly wider
                    _TickMark(color: colorScheme.outline.withValues(alpha: 0.35), width: 22, height: 1.5),
                    _TickMark(color: colorScheme.outline.withValues(alpha: 0.15), width: 14),
                    _TickMark(color: colorScheme.outline.withValues(alpha: 0.15), width: 14),
                  ],
                ),
              ),

              // Rotated vertical slider
              RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: isEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    inactiveTrackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    thumbColor: isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7.5,
                      elevation: 2,
                      pressedElevation: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    overlayColor: colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: value.clamp(-12.0, 12.0),
                    min: -12.0,
                    max: 12.0,
                    onChanged: isEnabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Frequency Label
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isEnabled
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _TickMark extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const _TickMark({
    required this.color,
    required this.width,
    this.height = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

/// Adaptive console container that evenly spaces sliders when width permits (desktop/tablet),
/// or enables smooth horizontal scrolling with generous touch targets when width is constrained (mobile).
class EqualizerBandsConsole extends StatelessWidget {
  final List<String> labels;
  final List<double> bands;
  final bool isEnabled;
  final void Function(int index, double value) onBandChanged;
  final double height;

  const EqualizerBandsConsole({
    super.key,
    required this.labels,
    required this.bands,
    required this.isEnabled,
    required this.onBandChanged,
    this.height = 180.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = labels.length;
          final availableWidth = constraints.maxWidth;
          final widthPerBand = count > 0 ? availableWidth / count : 50.0;

          // If available width allows at least 44dp per band, fit all bands without scrolling.
          // Otherwise, enable horizontal scrolling with a comfortable 48dp touch target per slider.
          final shouldScroll = widthPerBand < 44.0;

          if (!shouldScroll) {
            return Row(
              children: List.generate(count, (index) {
                return Expanded(
                  child: EqualizerBandSlider(
                    label: labels[index],
                    value: index < bands.length ? bands[index] : 0.0,
                    isEnabled: isEnabled,
                    onChanged: (val) => onBandChanged(index, val),
                  ),
                );
              }),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(count, (index) {
                return SizedBox(
                  width: 48.0,
                  child: EqualizerBandSlider(
                    label: labels[index],
                    value: index < bands.length ? bands[index] : 0.0,
                    isEnabled: isEnabled,
                    onChanged: (val) => onBandChanged(index, val),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
