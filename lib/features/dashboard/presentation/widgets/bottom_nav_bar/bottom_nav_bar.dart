import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

/// Modern animated bottom navigation bar with responsive hover states and active indicators.
class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  /// Translate logical index (0-5) to physical index (0-3)
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
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final physicalIndex = getPhysicalIndex(logicalIndex);

    final navItems = [
      (
        label: 'Home',
        regularIcon: UIcons.regular.home,
        solidIcon: UIcons.solid.home,
      ),
      (
        label: 'Explore',
        regularIcon: UIcons.regular.compass_alt,
        solidIcon: UIcons.solid.compass_alt,
      ),
      (
        label: 'Library',
        regularIcon: UIcons.regular.headphones,
        solidIcon: UIcons.solid.headphones,
      ),
      (
        label: 'Settings',
        regularIcon: UIcons.regular.settings,
        solidIcon: UIcons.solid.settings,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1116).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = physicalIndex == index;

              return Expanded(
                child: _NavBarItem(
                  label: item.label,
                  regularIcon: item.regularIcon,
                  solidIcon: item.solidIcon,
                  isSelected: isSelected,
                  primaryColor: primary,
                  onTap: () {
                    ref
                        .read(mainNavigationProvider.notifier)
                        .setIndex(getLogicalIndex(index));
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final String label;
  final IconData regularIcon;
  final IconData solidIcon;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.regularIcon,
    required this.solidIcon,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;
    final primary = widget.primaryColor;

    final Color iconColor = isSelected
        ? primary
        : (_isHovered
            ? primary.withValues(alpha: 0.8)
            : theme.colorScheme.onSurface.withValues(alpha: 0.5));

    final Color textColor = isSelected
        ? primary
        : (_isHovered
            ? primary.withValues(alpha: 0.8)
            : theme.colorScheme.onSurface.withValues(alpha: 0.5));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.12 : (isSelected ? 1.05 : 1.0),
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isSelected ? widget.solidIcon : widget.regularIcon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
