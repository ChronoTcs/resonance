import 'package:flutter/material.dart';

class ResonanceSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final IconData? iconLeft;
  final IconData? iconRight;
  final String? labelLeft;
  final String? labelRight;
  final ValueChanged<double> onChanged;

  const ResonanceSlider({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.iconLeft,
    this.iconRight,
    this.labelLeft,
    this.labelRight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;

    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (iconLeft != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(iconLeft, size: 18, color: theme.hintColor),
                  ),
                if (labelLeft != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      labelLeft!,
                      style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      activeTrackColor: activeColor,
                      inactiveTrackColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      thumbColor: activeColor,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6.0,
                      ),
                      overlayColor: activeColor.withValues(alpha: 0.12),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                      activeTickMarkColor: Colors.transparent,
                      inactiveTickMarkColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: divisions,
                      onChanged: onChanged,
                    ),
                  ),
                ),
                if (iconRight != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(iconRight, size: 18, color: theme.hintColor),
                  ),
                if (labelRight != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      labelRight!,
                      style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
