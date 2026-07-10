import 'package:flutter/material.dart';
import 'package:resonance/core/utils/app_icons.dart';

class OnlineTrackBadge extends StatelessWidget {
  const OnlineTrackBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Online Track',
      child: Icon(
        AppIcons.globe,
        size: 14,
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
      ),
    );
  }
}
