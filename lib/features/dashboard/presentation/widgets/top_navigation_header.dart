import 'package:flutter/material.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/search/unified_search_bar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_nav_tab_bar.dart';

/// Top application navigation bar coordinating navigation tabs and the unified search bar.
class TopNavigationHeader extends StatelessWidget {
  final Widget? left;
  final Widget? right;
  final List<Widget>? actions;

  const TopNavigationHeader({
    super.key,
    this.left,
    this.right,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDesktop = AppBreakpoints.isWide(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 49,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              // Left side: Custom widget or default category navigation tabs
              Expanded(
                child: left ?? const TopNavTabBar(),
              ),

              // Right side: Custom widget or unified search bar + actions
              right ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UnifiedSearchBar(),
                      if (actions != null) ...[
                        const SizedBox(width: 8),
                        ...actions!,
                      ],
                    ],
                  ),
            ],
          ),
        ),
        GlossyAnimatedBackground(
          isSelected: true,
          borderRadius: BorderRadius.zero,
          baseColor: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: const SizedBox(height: 1, width: double.infinity),
        ),
      ],
    );
  }
}
