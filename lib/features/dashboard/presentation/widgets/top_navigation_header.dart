import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/core/providers/search_history_provider.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      _overlayController.show();
    } else {
      // Delay hiding overlay briefly so button taps inside overlay (e.g. remove/clear) complete first
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          _overlayController.hide();
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
      ref.read(searchQueryProvider.notifier).setQuery(trimmed);
      ref.read(mainNavigationProvider.notifier).setIndex(1);
    }
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logicalIndex = ref.watch(mainNavigationProvider);
    final currentSearchQuery = ref.watch(searchQueryProvider);

    // Only sync controller from provider when field is NOT focused
    // (i.e. query was changed externally, not by the user typing here)
    if (!_searchFocusNode.hasFocus) {
      if (currentSearchQuery.isNotEmpty &&
          _searchController.text != currentSearchQuery) {
        _searchController.text = currentSearchQuery;
      } else if (currentSearchQuery.isEmpty &&
          _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
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
                child:
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
              ),

              // ── Right Side ──
              Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  widget.right ??
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Field with History Overlay
                          CompositedTransformTarget(
                            link: _layerLink,
                            child: OverlayPortal(
                              controller: _overlayController,
                              overlayChildBuilder: (context) {
                                final history = ref.watch(
                                  searchHistoryProvider,
                                );
                                if (history.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: CompositedTransformFollower(
                                    link: _layerLink,
                                    targetAnchor: Alignment.bottomLeft,
                                    followerAnchor: Alignment.topLeft,
                                    offset: const Offset(0, 4),
                                    child: Material(
                                      elevation: 8,
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      clipBehavior: Clip.antiAlias,
                                      child: Container(
                                        width: 240,
                                        constraints: const BoxConstraints(
                                          maxHeight: 220,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: theme.dividerColor
                                                .withValues(alpha: 0.12),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: SingleChildScrollView(
                                                physics:
                                                    const BouncingScrollPhysics(),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    for (final item in history)
                                                      InkWell(
                                                        onTap: () {
                                                          _searchController
                                                                  .text =
                                                              item;
                                                          _submitSearch(item);
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 8,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                UIcons
                                                                    .regular
                                                                    .clock,
                                                                size: 14,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  item,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: theme
                                                                        .colorScheme
                                                                        .onSurface,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                                onTap: () {
                                                                  ref
                                                                      .read(
                                                                        searchHistoryProvider
                                                                            .notifier,
                                                                      )
                                                                      .removeQuery(
                                                                        item,
                                                                      );
                                                                  if (history
                                                                          .length <=
                                                                      1) {
                                                                    _overlayController
                                                                        .hide();
                                                                  }
                                                                },
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        4.0,
                                                                      ),
                                                                  child: Icon(
                                                                    UIcons
                                                                        .regular
                                                                        .cross_small,
                                                                    size: 14,
                                                                    color: theme
                                                                        .colorScheme
                                                                        .onSurface
                                                                        .withValues(
                                                                          alpha:
                                                                              0.5,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            InkWell(
                                              onTap: () {
                                                ref
                                                    .read(
                                                      searchHistoryProvider
                                                          .notifier,
                                                    )
                                                    .clearAll();
                                                _overlayController.hide();
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.05),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      UIcons.regular.trash,
                                                      size: 12,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Clear Search History',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 240,
                                height: 36,
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onSubmitted: _submitSearch,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search songs online...',
                                    hintStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: theme.hintColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 13,
                                        ),
                                    prefixIcon: Icon(
                                      AppIcons.search,
                                      size: 14,
                                      color: theme.hintColor,
                                    ),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                        ? SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: Center(
                                              child: ReusableHoverIconButton(
                                                icon:
                                                    UIcons.regular.cross_small,
                                                iconSize: 14,
                                                padding: 2.0,
                                                scaleOnHover: 1.0,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                tooltip: 'Clear search',
                                                onTap: () {
                                                  _searchController.clear();
                                                  ref
                                                      .read(
                                                        searchQueryProvider
                                                            .notifier,
                                                      )
                                                      .setQuery('');
                                                },
                                              ),
                                            ),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 0,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
          child: const SizedBox(height: 1, width: double.infinity),
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
