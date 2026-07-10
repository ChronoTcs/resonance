import 'package:flutter/material.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';

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
    return ReusableHoverIconButton(
      icon: AppIcons.trash,
      tooltip: tooltip,
      color: Colors.red,
      iconSize: iconSize,
      onTap: onTap,
    );
  }
}
