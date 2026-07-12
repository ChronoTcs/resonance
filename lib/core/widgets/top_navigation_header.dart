import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/glossy_animated_background.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _searchController.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(BuildContext context, NotificationState notifState) {
    _hideOverlay();

    final theme = Theme.of(context);
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Click outside to dismiss detector
            GestureDetector(
              onTap: () {
                ref.read(notificationProvider.notifier).toggleDropdown(visible: false);
              },
              behavior: HitTestBehavior.translucent,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            Positioned(
              width: 320,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(-270, 40),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: theme.colorScheme.surface.withValues(alpha: 0.95),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dropdown Header
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Notifications',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (notifState.items.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    ref.read(notificationProvider.notifier).clearAll();
                                    ref.read(notificationProvider.notifier).toggleDropdown(visible: false);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Clear All',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Dropdown Content
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: notifState.items.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'No new notifications',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: notifState.items.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = notifState.items[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        item.isError
                                            ? UIcons.regular.exclamation
                                            : UIcons.regular.check,
                                        color: item.isError
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.primary,
                                        size: 16,
                                      ),
                                      title: Text(
                                        item.title,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: item.isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        item.message,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      onTap: () {
                                        // Mark as read
                                        ref.read(notificationProvider.notifier).markAllAsRead();
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logicalIndex = ref.watch(mainNavigationProvider);
    final currentSearchQuery = ref.watch(searchQueryProvider);
    final notifState = ref.watch(notificationProvider);

    // Sync search text field with global search query when search changes
    if (currentSearchQuery.isNotEmpty &&
        _searchController.text != currentSearchQuery) {
      _searchController.text = currentSearchQuery;
    } else if (currentSearchQuery.isEmpty &&
        _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    // Toggle overlay visibility based on state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notifState.isDropdownVisible) {
        _showOverlay(context, notifState);
      } else {
        _hideOverlay();
      }
    });

    final unreadCount = notifState.items.where((i) => !i.isRead).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: theme.colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Left Side ──
              widget.left ??
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
                  // Notification Bell with badge overlay
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ReusableHoverIconButton(
                          icon: UIcons.regular.bell,
                          tooltip: 'Notifications',
                          iconSize: 18,
                          onTap: () {
                            ref.read(notificationProvider.notifier).toggleDropdown();
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
