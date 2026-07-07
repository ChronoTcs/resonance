import 'dart:io';
import 'package:flutter/material.dart';

/// Sebuah widget tombol ikon "Dumb Component" yang reusable dengan animasi hover halus.
/// Mendukung adaptasi lintas platform (Windows Desktop vs Android Mobile).
class ReusableHoverIconButton extends StatefulWidget {
  final IconData? icon;
  final VoidCallback onTap;
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

  const ReusableHoverIconButton({
    super.key,
    this.icon,
    required this.onTap,
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
  });

  @override
  State<ReusableHoverIconButton> createState() => _ReusableHoverIconButtonState();
}

class _ReusableHoverIconButtonState extends State<ReusableHoverIconButton> {
  bool _isHovered = false;

  bool get _isWindows => Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.hoverColor ?? theme.primaryColor;

    // Warna dasar mengikuti status isDisabled dan isSelected
    final baseColor = widget.isDisabled 
        ? (widget.iconColor ?? widget.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.38)
        : (widget.isSelected 
            ? activeColor 
            : (widget.iconColor ?? widget.color ?? theme.colorScheme.onSurface));

    // ATURAN SOTA V2.3: Jika ada backgroundColor (Mode Filled), 
    // iconColor tidak boleh berubah jadi activeColor saat hover agar tidak 'tenggelam'.
    final finalIconColor = (widget.backgroundColor != null && _isHovered && !widget.isDisabled)
        ? (widget.iconColor ?? Colors.white)
        : (_isHovered && !widget.isDisabled && _isWindows ? activeColor : baseColor);

    // SOTA V6.0: Dynamic layout logic
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
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: finalIconColor,
                ),
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
              ? Icon(widget.icon, size: widget.iconSize, color: finalIconColor)
              : const SizedBox.shrink());
    }

    // Bentuk standar Resonance: Rounded Rectangle
    final borderRadius = BorderRadius.circular(8);

    Widget buttonContent = GestureDetector(
      onTap: widget.isDisabled ? null : widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: _isHovered && !widget.isDisabled ? widget.scaleOnHover : 1.0,
        curve: Curves.easeOutBack,
        child: ClipRect( // SOTA V3.6: Clip at the button level for the "reveal" effect
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(widget.padding),
            decoration: BoxDecoration(
              color: _isHovered && !widget.isDisabled
                  ? (widget.backgroundColor != null 
                      ? Color.lerp(widget.backgroundColor, Colors.white, 0.2) // Lighter on hover
                      : activeColor.withValues(alpha: 0.12))
                  : (widget.isSelected 
                      ? (widget.backgroundColor ?? Colors.transparent) 
                      : (widget.backgroundColor ?? Colors.transparent)),
              borderRadius: borderRadius,
              shape: BoxShape.rectangle,
              border: widget.isSelected && !widget.isDisabled
                  ? Border.all(color: activeColor.withValues(alpha: 0.5), width: 1) 
                  : (widget.backgroundColor != null && _isHovered && !widget.isDisabled
                      ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) 
                      : null),
            ),
            child: !_isWindows && !widget.isDisabled
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: borderRadius,
                      splashColor: (widget.backgroundColor ?? activeColor).withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: content,
                      ),
                    ),
                  )
                : content,
          ),
        ),
      ),
    );

    Widget result = Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: MouseRegion(
        cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) {
          if (!widget.isDisabled) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          setState(() => _isHovered = false);
        },
        child: _isHovered && !widget.isDisabled
            ? Tooltip(
                message: widget.tooltip,
                preferBelow: false,
                verticalOffset: 28, // Adjusted for clarity
                triggerMode: _isWindows ? TooltipTriggerMode.manual : TooltipTriggerMode.longPress,
                ignorePointer: true,
                child: buttonContent,
              )
            : buttonContent,
      ),
    );

    return result;
  }
}
