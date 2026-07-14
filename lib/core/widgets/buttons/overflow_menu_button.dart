import 'package:flutter/material.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'reusable_hover_icon_button.dart';

class OverflowMenuButton extends StatelessWidget {
  const OverflowMenuButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Actions',
    this.iconSize = 16.0,
    this.color,
  });

  final VoidCallback onTap;
  final String tooltip;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ReusableHoverIconButton(
      icon: AppIcons.moreVert,
      tooltip: tooltip,
      color: color,
      iconSize: iconSize,
      onTap: onTap,
    );
  }
}
