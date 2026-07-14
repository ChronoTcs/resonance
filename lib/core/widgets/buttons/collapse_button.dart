import 'package:flutter/material.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'reusable_hover_icon_button.dart';

class CollapseButton extends StatelessWidget {
  const CollapseButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Minimize',
    this.color,
    this.iconSize = 24.0,
  });

  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ReusableHoverIconButton(
      icon: AppIcons.collapseDown,
      tooltip: tooltip,
      color: color,
      iconSize: iconSize,
      onTap: onTap,
    );
  }
}
