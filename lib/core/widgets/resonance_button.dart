import 'package:flutter/material.dart';

enum ResonanceButtonStyle {
  primary,
  secondary,
  danger,
}

class ResonanceButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final ResonanceButtonStyle style;
  final bool isFullWidth;

  const ResonanceButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.style = ResonanceButtonStyle.primary,
    this.isFullWidth = false,
  });

  @override
  State<ResonanceButton> createState() => _ResonanceButtonState();
}

class _ResonanceButtonState extends State<ResonanceButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null;

    Color bg;
    Color fg;
    Color border = Colors.transparent;

    switch (widget.style) {
      case ResonanceButtonStyle.primary:
        bg = isEnabled
            ? (_isHovered
                ? theme.colorScheme.primary.withValues(alpha: 0.85)
                : theme.colorScheme.primary)
            : theme.disabledColor;
        fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black87;
        break;
      case ResonanceButtonStyle.secondary:
        bg = _isHovered
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surface.withValues(alpha: 0.4);
        fg = isEnabled ? theme.colorScheme.primary : theme.disabledColor;
        border = isEnabled
            ? (_isHovered
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.primary.withValues(alpha: 0.2))
            : theme.disabledColor.withValues(alpha: 0.2);
        break;
      case ResonanceButtonStyle.danger:
        bg = isEnabled
            ? (_isHovered
                ? theme.colorScheme.error.withValues(alpha: 0.85)
                : theme.colorScheme.error)
            : theme.disabledColor;
        fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black87;
        break;
    }

    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 14, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.isFullWidth ? double.infinity : null,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border != Colors.transparent ? Border.all(color: border, width: 1) : null,
          boxShadow: _isHovered && isEnabled && widget.style == ResonanceButtonStyle.primary
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: widget.isFullWidth ? null : 1.0,
                heightFactor: 1.0,
                child: buttonChild,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResonanceDropdown<T> extends StatefulWidget {
  final T value;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;
  final bool isExpanded;

  const ResonanceDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.items,
    this.isExpanded = false,
  });

  @override
  State<ResonanceDropdown<T>> createState() => _ResonanceDropdownState<T>();
}

class _ResonanceDropdownState<T> extends State<ResonanceDropdown<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? activeColor.withValues(alpha: 0.08)
              : theme.colorScheme.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered
                ? activeColor.withValues(alpha: 0.4)
                : theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: widget.value,
            onChanged: widget.onChanged,
            items: widget.items,
            isExpanded: widget.isExpanded,
            dropdownColor: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            focusColor: Colors.transparent,
            isDense: true,
            icon: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                const IconData(0xf13d, fontFamily: 'uicons-regular-rounded'), // angle_small_down
                size: 14,
                color: _isHovered ? activeColor : theme.iconTheme.color,
              ),
            ),
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
