import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_providers.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';

/// Dedicated top header bar for the right companion sidebar.
/// Sits at exactly 52px height to align symmetrically with the title bar and left sidebar.
class RightSidebarTopBar extends ConsumerWidget {
  const RightSidebarTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(rightSidebarExpandedProvider);

    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            top: 8,
            left: isExpanded ? null : 17,
            right: isExpanded ? 7 : null,
            child: ReusableHoverIconButton(
              icon: isExpanded
                  ? UIcons.regular.angle_small_right
                  : UIcons.regular.angle_small_left,
              tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
              onTap: () {
                final willExpand = !isExpanded;
                if (willExpand && !AppBreakpoints.canExpandDualSidebars(context)) {
                  ref.read(leftSidebarExpandedProvider.notifier).setExpanded(false);
                }
                ref
                    .read(rightSidebarExpandedProvider.notifier)
                    .setExpanded(willExpand);
              },
              iconSize: 20,
              padding: 8,
            ),
          ),
        ],
      ),
    );
  }
}
