import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';

/// Item descriptor for [ResonanceSegmentedBar].
class ResonanceSegmentItem {
  final String label;
  final IconData? icon;
  final String? tooltip;
  final bool isDismissible;
  final VoidCallback? onDismiss;

  const ResonanceSegmentItem({
    this.label = '',
    this.icon,
    this.tooltip,
    this.isDismissible = false,
    this.onDismiss,
  });
}

/// A modern, reusable morphing segmented navigation bar for mobile sub-navigation.
///
/// Automatically distributes segments equally across the available width:
/// - 2 items: 50% / 50% split (e.g. Music & Playlists)
/// - 3 items: 33.3% / 33.3% / 33.3% split (e.g. Music, Playlists, Downloads)
///
/// Supports smooth animated transitions when items appear or disappear,
/// active pill highlighting with primary theme accents, and dismiss buttons.
class ResonanceSegmentedBar extends StatelessWidget {
  final List<ResonanceSegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final EdgeInsetsGeometry padding;
  final Duration animationDuration;
  final Curve animationCurve;

  const ResonanceSegmentedBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 42.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.animationDuration = const Duration(milliseconds: 240),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: padding,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(3.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                key: ValueKey('segment_${items[i].label}'),
                child: _SegmentTile(
                  item: items[i],
                  isSelected: i == selectedIndex,
                  onTap: () => onSelected(i),
                  primaryColor: primaryColor,
                  animationDuration: animationDuration,
                  animationCurve: animationCurve,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final ResonanceSegmentItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SegmentTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isSelected
        ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.15)
        : Colors.transparent;

    final borderColor = isSelected
        ? primaryColor.withValues(alpha: 0.45)
        : Colors.transparent;

    final foregroundColor = isSelected
        ? primaryColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return AnimatedContainer(
      duration: animationDuration,
      curve: animationCurve,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Tooltip(
            message: item.tooltip ?? (item.label.isNotEmpty ? item.label : ''),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 14,
                      color: foregroundColor,
                    ),
                    if (item.label.isNotEmpty) const SizedBox(width: 6),
                  ],
                  if (item.label.isNotEmpty)
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: foregroundColor,
                        ),
                      ),
                    ),
                  if (item.isDismissible) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: item.onDismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          UIcons.regular.cross_small,
                          size: 13,
                          color: foregroundColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
