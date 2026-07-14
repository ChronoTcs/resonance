import 'package:flutter/material.dart';

class ResonanceContextMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const ResonanceContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });
}

class ResonanceContextMenu extends StatelessWidget {
  final List<ResonanceContextMenuItem> items;
  final Widget child;
  final String tooltip;

  const ResonanceContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.tooltip = 'More options',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        cardColor: theme.colorScheme.surface.withValues(alpha: 0.95),
        popupMenuTheme: popupMenuTheme(theme),
      ),
      child: PopupMenuButton<int>(
        tooltip: tooltip,
        itemBuilder: (context) => List.generate(items.length, (index) {
          final item = items[index];
          return PopupMenuItem<int>(
            value: index,
            onTap: item.onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: item.isDanger ? theme.colorScheme.error : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: item.isDanger ? theme.colorScheme.error : theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
        child: child,
      ),
    );
  }

  static PopupMenuThemeData popupMenuTheme(ThemeData theme) {
    return PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      elevation: 8,
    );
  }
}
