import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/explore/presentation/widgets/search_suggestion_tile.dart';
import 'package:resonance/features/explore/presentation/providers/recent_searches_provider.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';

/// Vertical list of search query suggestions matching Picture 2 ("You might also like").
class SearchSuggestionsSection extends ConsumerWidget {
  final String title;
  final ValueChanged<String> onSubmitQuery;
  final ValueChanged<String> onInsertQuery;

  const SearchSuggestionsSection({
    super.key,
    this.title = 'You might also like',
    required this.onSubmitQuery,
    required this.onInsertQuery,
  });

  static const List<String> _defaultFallbackSuggestions = [
    'don toliver',
    'ariana grande',
    'maren morris',
    'doja cat',
    'raye',
    'the weeknd',
    'billie eilish',
    'steve lacy',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchItems = ref.watch(recentSearchesProvider).value ?? [];
    final recentItems = searchItems.isNotEmpty
        ? searchItems
        : (ref.watch(recentlyPlayedProvider).value ?? []);

    // Derive contextual suggestions from user listening history
    final historyArtists = recentItems
        .map((e) => (e.artist ?? '').trim())
        .where((a) => a.isNotEmpty && a.toLowerCase() != 'unknown artist')
        .toSet()
        .toList();

    final List<String> suggestions = [];
    for (final artist in historyArtists) {
      if (!suggestions.contains(artist.toLowerCase())) {
        suggestions.add(artist.toLowerCase());
      }
      if (suggestions.length >= 4) break;
    }

    // Fill with default popular trending suggestions if needed
    for (final fallback in _defaultFallbackSuggestions) {
      if (!suggestions.contains(fallback)) {
        suggestions.add(fallback);
      }
      if (suggestions.length >= 7) break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final query = suggestions[index];
            return SearchSuggestionTile(
              query: query,
              onSubmit: onSubmitQuery,
              onInsert: onInsertQuery,
            );
          },
        ),
      ],
    );
  }
}
