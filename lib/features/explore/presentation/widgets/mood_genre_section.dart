import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';

class MoodGenreItem {
  final String title;
  final Color color;

  const MoodGenreItem(this.title, this.color);
}

/// Horizontal multi-row pill carousel matching Picture 5 ("Moods & genres").
///
/// Features:
/// - Header with "Moods & genres" title, "More" pill, and < > scroll controls.
/// - 4 rows x horizontal scrolling grid.
/// - Each pill has a charcoal container, 5dp vertical color bar on the left edge, and bold label.
/// - Tapping a pill triggers callback to filter/search for that mood or genre.
class MoodGenreSection extends StatefulWidget {
  final String title;
  final ValueChanged<String> onCategorySelected;

  const MoodGenreSection({
    super.key,
    this.title = 'Moods & genres',
    required this.onCategorySelected,
  });

  static const List<MoodGenreItem> defaultCategories = [
    // Column 1
    MoodGenreItem('Commute', Color(0xFFFFB300)),
    MoodGenreItem('Focus', Color(0xFF4FC3F7)),
    MoodGenreItem('Gaming', Color(0xFF26A69A)),
    MoodGenreItem('Feel Good', Color(0xFF4CAF50)),

    // Column 2
    MoodGenreItem('Workout', Color(0xFFFF9800)),
    MoodGenreItem('Party', Color(0xFFAB47BC)),
    MoodGenreItem('Romance', Color(0xFFE53935)),
    MoodGenreItem('Relax', Color(0xFF42A5F5)),

    // Column 3
    MoodGenreItem('Sad', Color(0xFFFFEE58)),
    MoodGenreItem('Energy Boost', Color(0xFFFFF176)),
    MoodGenreItem('Sleep', Color(0xFF5E35B1)),
    MoodGenreItem('African', Color(0xFF43A047)),

    // Column 4
    MoodGenreItem('Arabic', Color(0xFFFB8C00)),
    MoodGenreItem('Blues', Color(0xFF1E88E5)),
    MoodGenreItem('Bollywood & India', Color(0xFF3949AB)),
    MoodGenreItem('Country & Americana', Color(0xFF1565C0)),

    // Column 5
    MoodGenreItem('Dance & Electronic', Color(0xFF00ACC1)),
    MoodGenreItem('Dangdut', Color(0xFF5C6BC0)),
    MoodGenreItem('Decades', Color(0xFF81C784)),
    MoodGenreItem('Folk & Acoustic', Color(0xFF2E7D32)),

    // Column 6
    MoodGenreItem('Hip-Hop', Color(0xFFF4511E)),
    MoodGenreItem('Indie & Alternative', Color(0xFFECEFF1)),
    MoodGenreItem('Pop', Color(0xFFE53935)),
    MoodGenreItem('J-Pop', Color(0xFFD81B60)),
  ];

  @override
  State<MoodGenreSection> createState() => _MoodGenreSectionState();
}

class _MoodGenreSectionState extends State<MoodGenreSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      (_scrollController.offset - 354).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 354).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = MoodGenreSection.defaultCategories;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Nav Arrows (More button removed as instructed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReusableHoverIconButton(
                        icon: UIcons.regular.angle_small_left,
                        tooltip: 'Previous',
                        iconSize: 18,
                        onTap: _scrollLeft,
                      ),
                      const SizedBox(width: 4),
                      ReusableHoverIconButton(
                        icon: UIcons.regular.angle_small_right,
                        tooltip: 'Next',
                        iconSize: 18,
                        onTap: _scrollRight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4-Row Horizontal Scroll Grid
          SizedBox(
            height: 220,
            child: GridView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 44 / 155,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _buildMoodGenrePill(cat, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodGenrePill(MoodGenreItem cat, ThemeData theme) {
    return Material(
      color: const Color(0xFF212121),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () => widget.onCategorySelected(cat.title),
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // Colored left accent bar
              Container(
                width: 6,
                height: double.infinity,
                color: cat.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
