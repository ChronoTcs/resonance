import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_providers.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';

/// Top header bar for the left navigation sidebar.
/// Sits at exactly 52px height to align symmetrically with the title bar and right sidebar.
class LeftSidebarTopBar extends ConsumerWidget {
  const LeftSidebarTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(leftSidebarExpandedProvider);
    final theme = Theme.of(context);

    return Container(
      height: 52,
      alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.only(left: isExpanded ? 4 : 0),
      child: isExpanded
          ? Row(
              children: [
                ReusableHoverIconButton(
                  icon: UIcons.regular.waveform_path,
                  tooltip: 'Collapse Navigation',
                  onTap: () => ref.read(leftSidebarExpandedProvider.notifier).setExpanded(false),
                  iconSize: 20,
                  padding: 6,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Resonance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : ReusableHoverIconButton(
              icon: UIcons.regular.waveform_path,
              tooltip: 'Expand Navigation',
              onTap: () {
                if (!AppBreakpoints.canExpandDualSidebars(context)) {
                  ref.read(rightSidebarExpandedProvider.notifier).setExpanded(false);
                }
                ref.read(leftSidebarExpandedProvider.notifier).setExpanded(true);
              },
              iconSize: 20,
              padding: 8,
            ),
    );
  }
}
