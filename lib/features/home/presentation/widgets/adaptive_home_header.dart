import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';

/// Adaptive Home Header supporting both compact (mobile search/filter flow)
/// and wide (desktop title with global search bar) modes.
class AdaptiveHomeHeader extends StatelessWidget {
  final bool isCompact;
  final bool isSearchFieldOpen;
  final TextEditingController searchController;
  final ValueChanged<String> onSubmitSearch;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefresh;

  const AdaptiveHomeHeader({
    super.key,
    required this.isCompact,
    required this.isSearchFieldOpen,
    required this.searchController,
    required this.onSubmitSearch,
    required this.onToggleSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      return TopNavigationHeader(
        left: _CompactHomeHeaderContent(
          isSearchFieldOpen: isSearchFieldOpen,
          searchController: searchController,
          onSubmitSearch: onSubmitSearch,
        ),
        right: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReusableHoverIconButton(
              icon: isSearchFieldOpen
                  ? UIcons.regular.cross_small
                  : UIcons.regular.search,
              tooltip: isSearchFieldOpen ? 'Close search' : 'Search',
              iconSize: 18,
              onTap: onToggleSearch,
            ),
            const SizedBox(width: 6),
            ReusableHoverIconButton(
              icon: UIcons.regular.refresh,
              tooltip: 'Refresh feed',
              iconSize: 18,
              onTap: onRefresh,
            ),
          ],
        ),
      );
    }

    return TopNavigationHeader(
      left: Text(
        'Home',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        ReusableHoverIconButton(
          icon: UIcons.regular.refresh,
          tooltip: 'Refresh feed',
          iconSize: 18,
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _CompactHomeHeaderContent extends StatelessWidget {
  final bool isSearchFieldOpen;
  final TextEditingController searchController;
  final ValueChanged<String> onSubmitSearch;

  const _CompactHomeHeaderContent({
    required this.isSearchFieldOpen,
    required this.searchController,
    required this.onSubmitSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearchFieldOpen) {
      return TextField(
        controller: searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitSearch,
        decoration: const InputDecoration(
          hintText: 'Search songs, artists, albums...',
          border: InputBorder.none,
        ),
      );
    }

    final theme = Theme.of(context);
    return Text(
      'Resonance',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      ),
    );
  }
}

