import 'package:flutter/material.dart';

/// Tactile interactive action button inside the drag-and-drop zone.
/// Features explicit hover cursor, theme accent illumination, and tap feedback.
class DropZoneActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  const DropZoneActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  State<DropZoneActionButton> createState() => _DropZoneActionButtonState();
}

class _DropZoneActionButtonState extends State<DropZoneActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = widget.isPrimary
        ? (_isHovered ? primary.withValues(alpha: 0.22) : primary.withValues(alpha: 0.12))
        : (_isHovered
            ? colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.8 : 0.9)
            : colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.45 : 0.6));

    final Color borderColor = widget.isPrimary
        ? (_isHovered ? primary : primary.withValues(alpha: 0.45))
        : (_isHovered ? primary.withValues(alpha: 0.5) : colorScheme.outline.withValues(alpha: isDark ? 0.18 : 0.12));

    final Color contentColor = widget.isPrimary ? primary : (_isHovered ? primary : colorScheme.onSurface);

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.transparent,
          splashColor: primary.withValues(alpha: 0.15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: (widget.isPrimary ? primary : Colors.black).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: contentColor),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
