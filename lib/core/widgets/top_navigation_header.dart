import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import 'package:resonance_app/core/utils/app_icons.dart';
import 'package:resonance_app/core/providers/navigation_provider.dart';
import 'package:resonance_app/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';

class TopNavigationHeader extends ConsumerStatefulWidget {
  const TopNavigationHeader({super.key});

  @override
  ConsumerState<TopNavigationHeader> createState() => _TopNavigationHeaderState();
}

class _TopNavigationHeaderState extends ConsumerState<TopNavigationHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logicalIndex = ref.watch(mainNavigationProvider);
    final currentSearchQuery = ref.watch(searchQueryProvider);

    // Sync search text field with global search query when search changes
    if (currentSearchQuery.isNotEmpty && _searchController.text != currentSearchQuery) {
      _searchController.text = currentSearchQuery;
    } else if (currentSearchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Left: Navigation Tabs (Playlists, Artists, Albums, Podcasts) ──
          Row(
            children: [
              _buildTab('Playlists', targetIndex: 3, isActive: logicalIndex == 3),
              const SizedBox(width: 24),
              _buildTab('Artists', targetIndex: 2, isActive: logicalIndex == 2),
              const SizedBox(width: 24),
              _buildTab('Albums', targetIndex: 2, isActive: logicalIndex == 2),
              const SizedBox(width: 24),
              _buildTab('Podcasts', targetIndex: 1, isActive: logicalIndex == 1),
            ],
          ),

          // ── Right: Search Input, Notification, Profile ─────────────────────
          Row(
            children: [
              // Search Field
              Container(
                width: 240,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (query) {
                    final trimmed = query.trim();
                    ref.read(searchQueryProvider.notifier).setQuery(trimmed);
                    // Switch screen to Explore
                    ref.read(mainNavigationProvider.notifier).setIndex(1);
                  },
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                    prefixIcon: Icon(
                      AppIcons.search,
                      size: 16,
                      color: theme.hintColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Notification Bell
              ReusableHoverIconButton(
                icon: UIcons.regular.bell,
                tooltip: 'Notifications',
                iconSize: 18,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),

              // Profile Avatar
              Tooltip(
                message: 'Profile',
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(16),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                    child: Icon(
                      UIcons.regular.user,
                      size: 14,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, {required int targetIndex, required bool isActive}) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        ref.read(mainNavigationProvider.notifier).setIndex(targetIndex);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            width: 32,
            color: isActive ? theme.primaryColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
