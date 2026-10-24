import 'package:flutter/material.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
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
    final bool isDesktop = AppBreakpoints.isWide(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double horizontalPadding =
            maxW < 360 ? 12.0 : (isDesktop ? 24.0 : 16.0);
        // Calculate max allowed search bar width to guarantee space for left title and right actions
        final double dynamicSearchWidth =
            (maxW - (horizontalPadding * 2) - 110.0).clamp(120.0, 240.0);

        return Container(
          height: 49,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          color: Colors.transparent,
          child: Row(
            children: [
              // Left side: Custom widget or default category navigation tabs
              Expanded(
                child: left ?? const TopNavTabBar(),
              ),
              const SizedBox(width: 8),

              // Right side: Custom widget or unified search bar + actions
              right ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UnifiedSearchBar(
                        width: maxW < 480 ? dynamicSearchWidth : null,
                      ),
                      if (actions != null) ...[
                        const SizedBox(width: 8),
                        ...actions!,
                      ],
                    ],
                  ),
            ],
          ),
        );
      },
    );
  }
}
