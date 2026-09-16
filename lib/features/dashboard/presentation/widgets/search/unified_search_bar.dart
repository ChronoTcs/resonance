import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/search_history_provider.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/search/search_history_dropdown.dart';

/// Modern YouTube Music-style search bar that morphs into a unified card with search history.
class UnifiedSearchBar extends ConsumerStatefulWidget {
  final double? width;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;

  const UnifiedSearchBar({
    super.key,
    this.width,
    this.onSubmitted,
    this.hintText,
  });

  @override
  ConsumerState<UnifiedSearchBar> createState() => _UnifiedSearchBarState();
}

class _UnifiedSearchBarState extends ConsumerState<UnifiedSearchBar> {
  static const _searchTapRegionGroupId = 'search_history_tap_region';

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
    final history = ref.read(searchHistoryProvider);
    if (_searchFocusNode.hasFocus && history.isNotEmpty) {
      _overlayController.show();
    } else if (!_searchFocusNode.hasFocus) {
      _overlayController.hide();
    }
    setState(() {});
  }

  void _closeOverlay() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
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
      widget.onSubmitted?.call(trimmed);
      ref.read(mainNavigationProvider.notifier).setIndex(1); // Navigate to Explore
    }
    _closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSearchQuery = ref.watch(searchQueryProvider);
    final history = ref.watch(searchHistoryProvider);

    // Dismiss overlay and unfocus immediately on tab navigation
    ref.listen<int>(mainNavigationProvider, (previous, next) {
      if (previous != next) {
        _closeOverlay();
      }
    });

    // Close overlay if history becomes empty
    ref.listen<List<String>>(searchHistoryProvider, (previous, next) {
      if (next.isEmpty && _overlayController.isShowing) {
        _overlayController.hide();
        if (mounted) setState(() {});
      }
    });

    // Sync search input with external provider changes when not actively focused
    if (!_searchFocusNode.hasFocus) {
      if (currentSearchQuery.isNotEmpty &&
          _searchController.text != currentSearchQuery) {
        _searchController.text = currentSearchQuery;
      } else if (currentSearchQuery.isEmpty &&
          _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    }

    final bool isDesktop = AppBreakpoints.isWide(context);
    final double defaultWidth = isDesktop
        ? 240.0
        : (MediaQuery.sizeOf(context).width * 0.42).clamp(110.0, 200.0);
    final double searchWidth = widget.width ?? defaultWidth;

    final bool isExpanded =
        _searchFocusNode.hasFocus && history.isNotEmpty && _overlayController.isShowing;

    final BorderRadius searchBorderRadius = isExpanded
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          )
        : BorderRadius.circular(10);

    final Color searchBgColor = isExpanded
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    final BorderSide searchBorderSide = isExpanded
        ? BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 1,
          )
        : BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
          );

    final String placeholder = widget.hintText ??
        (isDesktop ? 'Search songs online...' : 'Search...');

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => TextFieldTapRegion(
          child: SearchHistoryDropdown(
            link: _layerLink,
            searchWidth: searchWidth,
            groupId: _searchTapRegionGroupId,
            onSelect: (item) {
              _searchController.text = item;
              _submitSearch(item);
            },
            onClose: _closeOverlay,
          ),
        ),
        child: TapRegion(
          groupId: _searchTapRegionGroupId,
          onTapOutside: (_) => _closeOverlay(),
          child: SizedBox(
            width: searchWidth,
            height: 36,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSubmitted: _submitSearch,
              groupId: _searchTapRegionGroupId,
              onTapOutside: (_) {
                // Intentionally empty: let the outer TapRegion(groupId) exclusively
                // handle dismiss. Without this, EditableText fires _defaultOnTapOutside
                // on pointer-DOWN, unmounting the dropdown before InkWell/button
                // can receive the pointer-UP (tap) event.
              },
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  AppIcons.search,
                  size: 14,
                  color: theme.hintColor,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: ReusableHoverIconButton(
                            icon: UIcons.regular.cross_small,
                            iconSize: 14,
                            padding: 2.0,
                            scaleOnHover: 1.0,
                            borderRadius: BorderRadius.circular(6),
                            tooltip: 'Clear search',
                            onTap: () {
                              _searchController.clear();
                              ref
                                  .read(searchQueryProvider.notifier)
                                  .setQuery('');
                            },
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: searchBgColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: searchBorderRadius,
                  borderSide: isExpanded ? searchBorderSide : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: searchBorderRadius,
                  borderSide: searchBorderSide,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: searchBorderRadius,
                  borderSide: isExpanded
                      ? searchBorderSide
                      : BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
