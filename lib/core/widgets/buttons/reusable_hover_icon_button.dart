import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Hover animation
class ReusableHoverIconButton extends StatefulWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color? color;
  final Color? iconColor;
  final Color? backgroundColor;
  final double iconSize;
  final double padding;
  final Color? hoverColor;
  final double scaleOnHover;
  final bool isDisabled;
  final bool isSelected;
  final String? label;
  final bool showLabel;
  final TextStyle? labelStyle;
  final EdgeInsets? margin;
  final Widget? child;
  final BorderRadius? borderRadius;

  const ReusableHoverIconButton({
    super.key,
    this.icon,
    this.onTap,
    required this.tooltip,
    this.color,
    this.iconColor,
    this.backgroundColor,
    this.iconSize = 24.0,
    this.padding = 8.0,
    this.hoverColor,
    this.scaleOnHover = 1.15,
    this.isDisabled = false,
    this.isSelected = false,
    this.label,
    this.showLabel = true,
    this.labelStyle,
    this.margin,
    this.child,
    this.borderRadius,
  });

  @override
  State<ReusableHoverIconButton> createState() => _ReusableHoverIconButtonState();
}

class _ReusableHoverIconButtonState extends State<ReusableHoverIconButton> {
  bool _isHovered = false;

  Widget _buildIcon(Color finalIconColor, Color activeColor) {
    return Icon(
      widget.icon,
      size: widget.iconSize,
      color: widget.isSelected ? activeColor : finalIconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.hoverColor ?? theme.primaryColor;

    // Base color based on isDisabled and isSelected status
    final baseColor = widget.isDisabled 
        ? (widget.iconColor ?? widget.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.38)
        : (widget.isSelected 
            ? activeColor 
            : (widget.iconColor ?? widget.color ?? theme.colorScheme.onSurface));

    // iconColor shouldn't change to activeColor on hover if a custom color/iconColor is specified.
    final finalIconColor = (widget.backgroundColor != null && _isHovered && !widget.isDisabled)
        ? (widget.iconColor ?? Colors.white)
        : (_isHovered && !widget.isDisabled
            ? (widget.iconColor ?? widget.color ?? activeColor)
            : baseColor);

    Widget content;
    if (widget.icon == null && widget.label != null) {
      // 1. Label-only mode (Example: Translation Button TRN/ROM)
      content = Center(
        child: Text(
          widget.label!,
          style: widget.labelStyle?.copyWith(color: finalIconColor) ??
              TextStyle(color: finalIconColor, fontSize: 13, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
      );
    } else if (widget.label != null) {
      // 2. Icon + Label mode (Example: Sidebar Navigation)
      content = Stack(
        clipBehavior: Clip.none, // Allow text to "reveal" outside during transition
        children: [
          // Non-positioned anchor so the Stack always has finite size
          Padding(
            padding: const EdgeInsets.only(left: 4), // Shift for 36px optical center
            child: SizedBox(
              width: widget.iconSize,
              height: widget.iconSize,
              child: Center(
                child: _buildIcon(finalIconColor, activeColor),
              ),
            ),
          ),
          // Sliding Text Layer with Fading
          Positioned(
            left: widget.iconSize + 16, // Consistent offset from anchor
            top: 0,
            bottom: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.showLabel ? 1.0 : 0.0,
              child: Center(
                child: Text(
                  widget.label!,
                  style: widget.labelStyle?.copyWith(color: finalIconColor) ??
                      TextStyle(color: finalIconColor, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // 3. Icon-only mode (Default behavior)
      content = widget.child ??
          (widget.icon != null
              ? _buildIcon(finalIconColor, activeColor)
              : const SizedBox.shrink());
    }

    // Bentuk standar Resonance: Rounded Rectangle
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(8);
    final isActiveHover = _isHovered && !widget.isDisabled;

    final Widget buttonContent = Transform.scale(
      scale: isActiveHover ? widget.scaleOnHover : 1.0,
      child: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: isActiveHover
                ? (widget.backgroundColor != null
                    ? Color.lerp(widget.backgroundColor, Colors.white, 0.2)
                    : activeColor.withValues(alpha: 0.12))
                : (widget.backgroundColor ?? Colors.transparent),
            borderRadius: borderRadius,
            shape: BoxShape.rectangle,
            border: widget.backgroundColor != null && isActiveHover
                ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isDisabled ? null : widget.onTap,
              borderRadius: borderRadius,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              child: Padding(
                padding: EdgeInsets.all(widget.padding),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    Widget interactiveChild = MouseRegion(
      cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.touch) return;
        if (!widget.isDisabled && !_isHovered) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) {
        if (_isHovered) {
          setState(() => _isHovered = false);
        }
      },
      child: buttonContent,
    );

    if (widget.tooltip.isNotEmpty && !widget.isDisabled) {
      interactiveChild = Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        verticalOffset: 28,
        triggerMode: TooltipTriggerMode.manual,
        ignorePointer: true,
        child: interactiveChild,
      );
    }

    return RepaintBoundary(
      child: Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: interactiveChild,
      ),
    );
  }
}
