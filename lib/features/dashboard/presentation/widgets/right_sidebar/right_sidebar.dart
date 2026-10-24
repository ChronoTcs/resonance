import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_queue_section.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_recommendation_section.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_top_bar.dart';

export 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';

/// Modern Right Companion Sidebar coordinator for Desktop layouts.
///
/// Houses the Playing Queue and Recommendations in a vertically stacked layout.
/// Features high-performance virtualized scrolling, isolated state invalidation,
/// and smooth width transitions between 58px (shrunk rail) and 310px (expanded panel)
/// with a unified single-hierarchy structure (no duplicate widgets or double-rendering).
class RightSidebar extends ConsumerWidget {
  const RightSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(rightSidebarExpandedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double targetWidth = isExpanded ? 310 : 70;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: targetWidth,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: targetWidth,
          maxWidth: targetWidth,
          child: SizedBox(
            width: targetWidth,
            child: RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RightSidebarTopBar(),
                  const Expanded(
                    flex: 1,
                    child: RightSidebarQueueSection(),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isExpanded ? 14 : 8),
                  child: Divider(
                    height: 12,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: RightSidebarRecommendationSection(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
