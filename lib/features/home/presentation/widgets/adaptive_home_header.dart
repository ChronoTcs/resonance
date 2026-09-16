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
        right: isSearchFieldOpen
            ? TextButton(
                onPressed: onToggleSearch,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReusableHoverIconButton(
                    icon: UIcons.regular.search,
                    tooltip: 'Search',
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
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: searchController,
        builder: (context, value, _) {
          return TextField(
            controller: searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitSearch,
            decoration: InputDecoration(
              hintText: 'Search songs, artists, albums...',
              border: InputBorder.none,
              suffixIcon: value.text.isNotEmpty
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: ReusableHoverIconButton(
                          icon: UIcons.regular.cross_small,
                          tooltip: 'Clear text',
                          iconSize: 16,
                          padding: 2.0,
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            searchController.clear();
                          },
                        ),
                      ),
                    )
                  : null,
            ),
          );
        },
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

