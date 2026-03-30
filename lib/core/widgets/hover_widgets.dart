import 'package:flutter/material.dart';

/// A wrapper that applies a "Modern Hover" effect to its child:
/// 1. 1.1x scaling on hover.
/// 2. Optional background color transition.
/// 3. Smooth 200ms animations.
class HoverWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? hoverColor;
  final bool useScale;
  final bool isTransparent;
  final EdgeInsets? padding;

  const HoverWrapper({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverColor,
    this.useScale = true,
    this.isTransparent = false,
    this.padding,
    this.forceHoverEffect = false,
  }) : super(key: key);

  final bool forceHoverEffect;

  @override
  State<HoverWrapper> createState() => _HoverWrapperState();
}

class _HoverWrapperState extends State<HoverWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Adaptive hover background: slightly higher opacity in dark mode for visibility
    final Color effectiveHoverColor = widget.hoverColor ?? 
        (isDark ? colorScheme.onSurface.withOpacity(0.12) : colorScheme.primary.withOpacity(0.08));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: (widget.onTap != null || widget.onLongPress != null) ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        hoverColor: Colors.transparent, // We handle hover manually for smooth animation
        splashColor: (widget.hoverColor ?? colorScheme.primary).withOpacity(0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding ?? const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered && !widget.isTransparent && (widget.onTap != null || widget.onLongPress != null || widget.forceHoverEffect)
                ? effectiveHoverColor
                : Colors.transparent,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          child: AnimatedScale(
            scale: _isHovered && widget.useScale && (widget.onTap != null || widget.onLongPress != null || widget.forceHoverEffect) ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A drop-in replacement for IconButton that uses the "Modern Hover" system.
class ModernIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double iconSize;
  final Color? color;
  final double padding;

  const ModernIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconSize = 24,
    this.color,
    this.padding = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: HoverWrapper(
        onTap: onPressed,
        padding: EdgeInsets.all(padding),
        child: IconTheme(
          data: IconThemeData(
            size: iconSize,
            color: onPressed == null 
                ? colorScheme.onSurface.withOpacity(0.3)
                : (color ?? colorScheme.onSurfaceVariant.withOpacity(0.8)),
          ),
          child: icon,
        ),
      ),
    );
  }
}
