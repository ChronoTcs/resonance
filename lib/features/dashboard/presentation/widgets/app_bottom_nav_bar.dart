import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  /// Translate logical index (0-5) to physical BottomNavigationBar index (0-3)
  static int getPhysicalIndex(int logicalIdx) {
    if (logicalIdx == 0) return 0; // Home (0)
    if (logicalIdx == 1) return 1; // Explore (1)
    if (logicalIdx <= 4) return 2; // Library, Playlists, Downloads -> Library (2)
    return 3; // Settings -> Settings (3)
  }

  /// Translate physical tap (0-3) back to logical index (0-5)
  static int getLogicalIndex(int physicalIdx) {
    if (physicalIdx == 0) return 0; // Home
    if (physicalIdx == 1) return 1; // Explore
    if (physicalIdx == 2) return 2; // Library
    return 5; // Settings
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logicalIndex = ref.watch(mainNavigationProvider);
    final theme = Theme.of(context);
    final physicalIndex = getPhysicalIndex(logicalIndex);

    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        currentIndex: physicalIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.primaryColor,
        unselectedItemColor: theme.iconTheme.color?.withValues(alpha: 0.5),
        enableFeedback: false,
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
            icon: Icon(UIcons.regular.settings),
            activeIcon: Icon(UIcons.solid.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
