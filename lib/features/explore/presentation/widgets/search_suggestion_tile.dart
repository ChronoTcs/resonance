import 'package:flutter/material.dart';
import 'package:resonance/core/widgets/widgets.dart';

/// Suggestion row matching Picture 2 ("You might also like").
///
/// Features:
/// - Leading search magnifying glass icon.
/// - Query text in white.
/// - Trailing diagonal arrow (arrow_outward) for inserting text into search box.
/// - Tapping row submits search; tapping arrow inserts without submitting.
class SearchSuggestionTile extends StatelessWidget {
  final String query;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onInsert;

  const SearchSuggestionTile({
    super.key,
    required this.query,
    required this.onSubmit,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: () => onSubmit(query),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              size: 22,
              color: Colors.white70,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                query,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            ReusableHoverIconButton(
              icon: Icons.arrow_outward,
              tooltip: 'Insert into search',
              iconSize: 18,
              padding: 6.0,
              iconColor: Colors.white70,
              borderRadius: BorderRadius.circular(6),
              onTap: () => onInsert(query),
            ),
          ],
        ),
      ),
    );
  }
}
