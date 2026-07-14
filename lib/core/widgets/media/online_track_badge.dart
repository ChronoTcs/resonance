import 'package:flutter/material.dart';
import 'package:resonance/core/utils/app_icons.dart';

class OnlineTrackBadge extends StatelessWidget {
  const OnlineTrackBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Online Track',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          AppIcons.globe,
          size: 10,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
