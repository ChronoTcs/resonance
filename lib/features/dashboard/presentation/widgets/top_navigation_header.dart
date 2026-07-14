import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/notification_bell.dart';

class TopNavigationHeader extends ConsumerStatefulWidget {
  final Widget? left;
  final Widget? right;
  const TopNavigationHeader({super.key, this.left, this.right});

  @override
  ConsumerState<TopNavigationHeader> createState() =>
      _TopNavigationHeaderState();
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
    if (currentSearchQuery.isNotEmpty &&
        _searchController.text != currentSearchQuery) {
      _searchController.text = currentSearchQuery;
    } else if (currentSearchQuery.isEmpty &&
        _searchController.text.isNotEmpty) {
      _searchController.clear();
    }



    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              // ── Left Side — Expanded so right cluster is always pinned to same edge ──
              Expanded(
                child: widget.left ??
                    Row(
                      children: [
                        _buildTab(
                          'Playlists',
                          targetIndex: 3,
                          isActive: logicalIndex == 3,
                        ),
                        const SizedBox(width: 24),
                        _buildTab(
                          'Artists',
                          targetIndex: 2,
                          isActive: logicalIndex == 2,
                        ),
                        const SizedBox(width: 24),
                        _buildTab(
                          'Albums',
                          targetIndex: 2,
                          isActive: logicalIndex == 2,
                        ),
                        const SizedBox(width: 24),
                        _buildTab(
                          'Podcasts',
                          targetIndex: 1,
                          isActive: logicalIndex == 1,
                        ),
                      ],
                    ),
              ),

              // ── Right Side ──
              Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  widget.right ??
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Field
                          SizedBox(
                            width: 240,
                            height: 36,
                            child: TextField(
                              controller: _searchController,
                              onSubmitted: (query) {
                                final trimmed = query.trim();
                                ref
                                    .read(searchQueryProvider.notifier)
                                    .setQuery(trimmed);
                                // Switch screen to Explore
                                ref.read(mainNavigationProvider.notifier).setIndex(1);
                              },
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search songs online...',
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.hintColor.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  AppIcons.search,
                                  size: 14,
                                  color: theme.hintColor,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.dividerColor.withValues(alpha: 0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(width: 12),
                  // Notification Bell — self-contained widget (reads notificationProvider internally)
                  const NotificationBell(),
                ],
              ),
            ],
          ),
        ),
        GlossyAnimatedBackground(
          isSelected: true,
          borderRadius: BorderRadius.zero,
          baseColor: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: theme.primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: const SizedBox(
            height: 1,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildTab(
    String label, {
    required int targetIndex,
    required bool isActive,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        ref.read(mainNavigationProvider.notifier).setIndex(targetIndex);
      },
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
