import 'package:flutter/material.dart';

class ResonanceSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ResonanceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ResonanceSwitch> createState() => _ResonanceSwitchState();
}

class _ResonanceSwitchState extends State<ResonanceSwitch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;
    final inactiveTrackColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final inactiveBorderColor = theme.dividerColor.withValues(alpha: 0.15);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 24,
          decoration: BoxDecoration(
            color: widget.value
                ? (_isHovered ? Color.lerp(activeColor, Colors.white, 0.1) : activeColor)
                : (_isHovered ? Color.lerp(inactiveTrackColor, Colors.white, 0.05) : inactiveTrackColor),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.value ? Colors.transparent : inactiveBorderColor,
              width: 1,
            ),
          ),
          alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.all(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: widget.value ? Colors.white : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
              boxShadow: widget.value
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
