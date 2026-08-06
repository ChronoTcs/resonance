import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'reusable_hover_icon_button.dart';

class DangerIconButton extends StatelessWidget {
  const DangerIconButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Delete',
    this.iconSize = 24.0,
  });

  final VoidCallback onTap;
  final String tooltip;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return ReusableHoverIconButton(
      icon: UIcons.regular.trash,
      tooltip: tooltip,
      color: errorColor,
      iconColor: errorColor,
      hoverColor: errorColor.withValues(alpha: 0.15),
      iconSize: iconSize,
      onTap: onTap,
    );
  }
}
