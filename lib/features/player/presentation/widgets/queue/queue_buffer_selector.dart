import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';

/// Reusable buffer size selector pill (N+1 to N+20).
class QueueBufferSelector extends StatelessWidget {
  final int currentSize;
  final ValueChanged<int> onSelected;

  const QueueBufferSelector({
    super.key,
    required this.currentSize,
    required this.onSelected,
  });

  static const List<int> availableSizes = [1, 2, 5, 10, 20];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<int>(
      tooltip: 'Adjust queue buffer',
      initialValue: currentSize,
      onSelected: onSelected,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(UIcons.regular.settings_sliders, size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'N+$currentSize',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(UIcons.regular.angle_small_down, size: 14, color: theme.colorScheme.primary),
          ],
        ),
      ),
      itemBuilder: (context) => availableSizes.map((size) {
        final isSelected = size == currentSize;
        return PopupMenuItem<int>(
          value: size,
          height: 38,
          child: Row(
            children: [
              Text(
                'N+$size tracks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_rounded, size: 16, color: theme.colorScheme.primary),
            ],
          ),
        );
      }).toList(),
    );
  }
}
