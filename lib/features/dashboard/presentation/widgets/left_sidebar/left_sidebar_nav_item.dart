import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

/// Interactive navigation pill item for the left navigation sidebar.
/// Clean, static typography & icon aesthetics without redundant looping shimmer animations.
class LeftSidebarNavItem extends ConsumerWidget {
  final int index;
  final String title;
  final IconData iconData;
  final IconData selectedIconData;
  final bool isExpanded;

  const LeftSidebarNavItem({
    super.key,
    required this.index,
    required this.title,
    required this.iconData,
    required this.selectedIconData,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(mainNavigationProvider);
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final content = Material(
      color: isSelected
          ? (isDark ? const Color(0xFF1E222B) : Colors.white)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      elevation: isSelected ? (isDark ? 2 : 3) : 0,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
      child: InkWell(
        onTap: () => ref.read(mainNavigationProvider.notifier).setIndex(index),
        borderRadius: BorderRadius.circular(14),
        hoverColor: primary.withValues(alpha: 0.08),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 10 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isSelected && isDark
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIconData : iconData,
                size: 18,
                color: isSelected
                    ? primary
                    : theme.iconTheme.color!.withValues(alpha: 0.55),
              ),
              if (isExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: isExpanded
          ? content
          : Tooltip(
              message: title,
              preferBelow: false,
              child: content,
            ),
    );
  }
}
