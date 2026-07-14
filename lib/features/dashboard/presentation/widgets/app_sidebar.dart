import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';

class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({super.key});

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  bool _isExtended = false;

  @override
  Widget build(BuildContext context) {
    final logicalIndex = ref.watch(mainNavigationProvider);
    final theme = Theme.of(context);

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isExtended ? 160 : 50,
          color: theme.navigationRailTheme.backgroundColor ?? theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hamburger Menu
              Container(
                height: 50,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 4),
                child: ReusableHoverIconButton(
                  icon: UIcons.regular.waveform_path,
                  tooltip: _isExtended ? 'Close Navigation' : 'Open Navigation',
                  onTap: () {
                    setState(() {
                      _isExtended = !_isExtended;
                    });
                  },
                  iconSize: 20,
                  padding: 10,
                ),
              ),
              // Navigation Items
              Expanded(
                child: Stack(
                  children: [
                    // Floating Active Indicator
                    if (logicalIndex != 5)
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        tween: Tween<double>(
                          begin: logicalIndex * 38.0,
                          end: logicalIndex * 38.0,
                        ),
                        builder: (context, value, child) {
                          return Positioned(
                            top: value + 2.0,
                            left: 0,
                            child: Container(
                              width: 3,
                              height: 34,
                              margin: const EdgeInsets.only(left: 4),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    // Nav items list
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNavItem(0, 'Home', UIcons.regular.home, UIcons.solid.home),
                          _buildNavItem(1, 'Explore', UIcons.regular.compass_alt, UIcons.solid.compass_alt),
                          _buildNavItem(2, 'Library', UIcons.regular.headphones, UIcons.solid.headphones),
                          _buildNavItem(3, 'Playlists', UIcons.regular.list_music, UIcons.solid.list_music),
                          _buildNavItem(4, 'Download', UIcons.regular.download, UIcons.solid.download),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Settings Button positioned at the bottom of the rail
              Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      tween: Tween<double>(
                        begin: logicalIndex == 5 ? 0.0 : 38.0,
                        end: logicalIndex == 5 ? 0.0 : 38.0,
                      ),
                      builder: (context, value, child) {
                        if (value >= 34.0) return const SizedBox.shrink();
                        return Positioned(
                          top: value + 2.0,
                          left: 0,
                          child: Container(
                            width: 3,
                            height: 34,
                            margin: const EdgeInsets.only(left: 4),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _buildNavItem(5, 'Settings', UIcons.regular.settings, UIcons.solid.settings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GlossyAnimatedBackground(
          isSelected: true,
          borderRadius: BorderRadius.zero,
          baseColor: Colors.transparent,
          border: Border(
            right: BorderSide(
              color: theme.primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: const SizedBox(
            width: 1,
            height: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, String title, IconData iconData, IconData selectedIconData) {
    final selectedIndex = ref.watch(mainNavigationProvider);
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);

    final activeColor = theme.primaryColor;
    final inactiveColor = theme.iconTheme.color!.withValues(alpha: 0.5);
    final color = isSelected ? activeColor : inactiveColor;

    return ReusableHoverIconButton(
      icon: isSelected ? selectedIconData : iconData,
      tooltip: title,
      onTap: () {
        ref.read(mainNavigationProvider.notifier).setIndex(index);
      },
      color: color,
      hoverColor: theme.primaryColor,
      iconSize: 18,
      padding: 8,
      isSelected: isSelected,
      scaleOnHover: 1.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      label: title,
      showLabel: _isExtended,
      labelStyle: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
