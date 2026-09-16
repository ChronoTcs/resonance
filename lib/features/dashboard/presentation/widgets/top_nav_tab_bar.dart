import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

/// Navigation item model for top bar tabs.
class TopNavTabItem {
  final String label;
  final int targetIndex;

  const TopNavTabItem({required this.label, required this.targetIndex});
}

/// Category navigation tabs for the top app header with active indicator underlines.
class TopNavTabBar extends ConsumerWidget {
  final List<TopNavTabItem>? items;

  const TopNavTabBar({super.key, this.items});

  static const List<TopNavTabItem> defaultItems = [
    TopNavTabItem(label: 'Playlists', targetIndex: 3),
    TopNavTabItem(label: 'Artists', targetIndex: 2),
    TopNavTabItem(label: 'Albums', targetIndex: 2),
    TopNavTabItem(label: 'Podcasts', targetIndex: 1),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logicalIndex = ref.watch(mainNavigationProvider);
    final tabItems = items ?? defaultItems;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tabItems.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            _TopNavTab(
              label: tabItems[i].label,
              isActive: logicalIndex == tabItems[i].targetIndex,
              onTap: () {
                ref.read(mainNavigationProvider.notifier).setIndex(tabItems[i].targetIndex);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TopNavTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TopNavTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Center(
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? theme.primaryColor : theme.hintColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: double.infinity,
                color: isActive ? theme.primaryColor : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
