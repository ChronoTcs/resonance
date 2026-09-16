import 'package:flutter/material.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/collapse_button.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';

/// Modular top header bar for the Queue screen.
class QueueHeaderBar extends StatelessWidget {
  final int totalUpcoming;
  final VoidCallback onClose;
  final VoidCallback onClearUpcoming;

  const QueueHeaderBar({
    super.key,
    required this.totalUpcoming,
    required this.onClose,
    required this.onClearUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = AppBreakpoints.isCompact(context);
    final iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Row(
        children: [
          CollapseButton(
            tooltip: 'Close queue',
            iconSize: 20,
            color: iconColor,
            onTap: onClose,
          ),
          const SizedBox(width: 8),
          Text(
            isCompact ? 'Queue' : 'PLAY QUEUE',
            style: TextStyle(
              fontSize: isCompact ? 14 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: isCompact ? 0.5 : 2,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 8),
          // Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isCompact ? '$totalUpcoming' : '$totalUpcoming upcoming',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Spacer(),

          if (totalUpcoming > 0)
            ReusableHoverIconButton(
              icon: UIcons.regular.trash,
              tooltip: 'Clear upcoming',
              iconSize: 18,
              color: iconColor,
              onTap: onClearUpcoming,
            ),
        ],
      ),
    );
  }
}
