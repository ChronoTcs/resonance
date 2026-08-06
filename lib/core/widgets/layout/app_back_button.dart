import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../buttons/reusable_hover_icon_button.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap, this.color});
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ReusableHoverIconButton(
      icon: UIcons.regular.angle_small_left,
      tooltip: 'Back',
      color: color,
      iconSize: 20,
      onTap: onTap ?? () => Navigator.maybePop(context),
    );
  }
}
