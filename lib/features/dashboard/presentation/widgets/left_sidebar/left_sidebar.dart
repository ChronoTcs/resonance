import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_nav_item.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_providers.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_top_bar.dart';

export 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_providers.dart';

/// Modern Left Navigation Sidebar for Desktop layouts.
/// Sits directly on the canvas without vertical divider borders.
/// Offers smooth extend/shrink transitions (50px rail to 180px panel) with elevated active card pills.
class LeftSidebar extends ConsumerWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(leftSidebarExpandedProvider);
    final theme = Theme.of(context);

    final double targetWidth = isExpanded ? 180 : 50;

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header / Logo + Toggle
                  const LeftSidebarTopBar(),
                  const SizedBox(height: 8),

                  // Main Navigation Items
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                              child: Text(
                                'RECOMMEND',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          LeftSidebarNavItem(
                            index: 0,
                            title: 'For you',
                            iconData: UIcons.regular.home,
                            selectedIconData: UIcons.solid.home,
                            isExpanded: isExpanded,
                          ),
                          LeftSidebarNavItem(
                            index: 1,
                            title: 'Explore',
                            iconData: UIcons.regular.compass_alt,
                            selectedIconData: UIcons.solid.compass_alt,
                            isExpanded: isExpanded,
                          ),
                          LeftSidebarNavItem(
                            index: 2,
                            title: 'Library',
                            iconData: UIcons.regular.headphones,
                            selectedIconData: UIcons.solid.headphones,
                            isExpanded: isExpanded,
                          ),

                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
                              child: Text(
                                'MY MUSIC',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 8),

                          LeftSidebarNavItem(
                            index: 3,
                            title: 'Playlists',
                            iconData: UIcons.regular.list_music,
                            selectedIconData: UIcons.solid.list_music,
                            isExpanded: isExpanded,
                          ),
                          LeftSidebarNavItem(
                            index: 4,
                            title: 'Downloads',
                            iconData: UIcons.regular.download,
                            selectedIconData: UIcons.solid.download,
                            isExpanded: isExpanded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Settings Button at bottom
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LeftSidebarNavItem(
                      index: 5,
                      title: 'Settings',
                      iconData: UIcons.regular.settings,
                      selectedIconData: UIcons.solid.settings,
                      isExpanded: isExpanded,
                    ),
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
