import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';

/// Canonical floating inset bottom sheet shell used across the Resonance application.
/// Consolidates backdrop blur, responsive inset layout, drag handle, outside-tap dismiss,
/// header typography, and calibrated close button into a single flat container.
class FloatingSheetShell extends StatelessWidget {
  final Widget? customHeader;
  final String? title;
  final IconData? icon;
  final VoidCallback? onClose;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry? padding;
  final bool isScrollable;
  final List<Widget> children;

  const FloatingSheetShell({
    super.key,
    this.customHeader,
    this.title,
    this.icon,
    this.onClose,
    this.maxWidth,
    this.maxHeight,
    this.padding,
    this.isScrollable = true,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark
        ? colorScheme.surface.withValues(alpha: 0.94)
        : colorScheme.surface.withValues(alpha: 0.98);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    final resolvedMaxHeight = maxHeight ?? MediaQuery.sizeOf(context).height * 0.88;

    final Widget dragHandle = Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    Widget? headerWidget;
    if (customHeader != null) {
      headerWidget = customHeader;
    } else if (title != null) {
      headerWidget = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: primary, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.cross_small,
            tooltip: 'Close',
            iconSize: 13.0,
            padding: 6.0,
            onTap: onClose ?? () => Navigator.pop(context),
          ),
        ],
      );
    }

    final columnChildren = <Widget>[
      dragHandle,
      if (headerWidget != null) ...[
        headerWidget,
        const SizedBox(height: 16),
      ],
      ...children,
    ];

    final contentWidget = isScrollable
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columnChildren,
              ),
            ),
          )
        : Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columnChildren,
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? 480,
              maxHeight: resolvedMaxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: GestureDetector(
                onTap: () {}, // Absorb inside card clicks
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sheetBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: contentWidget,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
