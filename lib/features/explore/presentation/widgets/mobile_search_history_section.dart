import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/providers/search_history_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/presentation/widgets/mood_genre_section.dart';
import 'package:resonance/features/explore/presentation/widgets/search_suggestions_section.dart';

/// Full mobile search history area displayed when the search bar is active.
///
/// Features:
/// 1. "Recent searches" header with clock icon and "Clear all" button.
/// 2. List of text queries from [searchHistoryProvider] with:
///    - Leading clock icon (UIcons.regular.time_past)
///    - Query text with ellipsis
///    - Trailing insert arrow (Icons.arrow_outward) to insert into search bar
///    - Trailing remove button (UIcons.regular.cross_small) to delete item
/// 3. Real-time prefix filtering when [filterText] is non-empty.
/// 4. Seamless companion with search suggestions and moods & genres.
class MobileSearchHistorySection extends ConsumerWidget {
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onInsert;
  final String filterText;

  const MobileSearchHistorySection({
    super.key,
    required this.onSelect,
    required this.onInsert,
    this.filterText = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allHistory = ref.watch(searchHistoryProvider);

    final cleanFilter = filterText.trim().toLowerCase();
    final history = cleanFilter.isEmpty
        ? allHistory
        : allHistory.where((q) => q.toLowerCase().contains(cleanFilter)).toList();

    return SilkyCustomScrollView(
      slivers: [
        if (history.isNotEmpty) ...[
          // Header: "Recent searches" + "Clear all"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        UIcons.regular.time_past,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cleanFilter.isEmpty ? 'Recent searches' : 'Matching searches',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  if (cleanFilter.isEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(searchHistoryProvider.notifier).clearAll();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear all',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // List of search history text items
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final query = history[index];
                return InkWell(
                  onTap: () => onSelect(query),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          UIcons.regular.time_past,
                          size: 18,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            query,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Insert text button (puts query in search input for editing)
                        ReusableHoverIconButton(
                          icon: Icons.arrow_outward,
                          tooltip: 'Insert into search',
                          iconSize: 18,
                          padding: 6.0,
                          iconColor: colorScheme.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => onInsert(query),
                        ),
                        const SizedBox(width: 2),
                        // Remove single query button
                        ReusableHoverIconButton(
                          icon: UIcons.regular.cross_small,
                          tooltip: 'Remove',
                          iconSize: 18,
                          padding: 6.0,
                          iconColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            ref.read(searchHistoryProvider.notifier).removeQuery(query);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: history.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // Suggestions fallback / companion
        SliverToBoxAdapter(
          child: SearchSuggestionsSection(
            title: history.isEmpty ? 'Search suggestions' : 'You might also like',
            onSubmitQuery: onSelect,
            onInsertQuery: onInsert,
          ),
        ),

        // Moods & genres
        SliverToBoxAdapter(
          child: MoodGenreSection(
            title: 'Moods & genres',
            onCategorySelected: (category) => onSelect('$category music'),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
