import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logicalIndex = ref.watch(mainNavigationProvider);
    final theme = Theme.of(context);

    // Translate logical index (0-5) to physical BottomNavigationBar index (0-4)
    int getPhysicalIndex(int logicalIdx) {
      if (logicalIdx == 3) return 2; // Playlists -> Library
      if (logicalIdx > 3) {
        return logicalIdx - 1; // Download (4->3), Settings (5->4)
      }
      return logicalIdx;
    }

    // Translate physical tap (0-4) back to logical index (0-5)
    int getLogicalIndex(int physicalIdx) {
      if (physicalIdx >= 3) {
        return physicalIdx + 1; // 3->4 (Download), 4->5 (Settings)
      }
      return physicalIdx;
    }

    final physicalIndex = getPhysicalIndex(logicalIndex);

    return BottomNavigationBar(
      currentIndex: physicalIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.primaryColor,
      unselectedItemColor: theme.iconTheme.color?.withValues(alpha: 0.5),
      onTap: (int index) {
        ref.read(mainNavigationProvider.notifier).setIndex(getLogicalIndex(index));
      },
      items: [
        BottomNavigationBarItem(
          icon: Icon(UIcons.regular.home),
          activeIcon: Icon(UIcons.solid.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(UIcons.regular.compass_alt),
          activeIcon: Icon(UIcons.solid.compass_alt),
          label: 'Explore',
        ),
        BottomNavigationBarItem(
          icon: Icon(UIcons.regular.headphones),
          activeIcon: Icon(UIcons.solid.headphones),
          label: 'Library',
        ),
        BottomNavigationBarItem(
          icon: Icon(UIcons.regular.download),
          activeIcon: Icon(UIcons.solid.download),
          label: 'Download',
        ),
        BottomNavigationBarItem(
          icon: Icon(UIcons.regular.settings),
          activeIcon: Icon(UIcons.solid.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
