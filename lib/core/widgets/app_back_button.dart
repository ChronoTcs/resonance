import 'package:flutter/material.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap, this.color});
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ReusableHoverIconButton(
      icon: AppIcons.back,
      tooltip: 'Back',
      color: color,
      onTap: onTap ?? () => Navigator.maybePop(context),
    );
  }
}
