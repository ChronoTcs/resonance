import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/home/presentation/widgets/speed_dial_card.dart';

/// Standalone Speed Dial section rendering a 2-row horizontal bento grid.
///
/// Matches YouTube Music "Speed dial" (Picture 4).
class SpeedDialSection extends ConsumerStatefulWidget {
  final String? subtitle;
  final String title;

  const SpeedDialSection({
    super.key,
    this.subtitle,
    this.title = 'Speed dial',
  });

  @override
  ConsumerState<SpeedDialSection> createState() => _SpeedDialSectionState();
}

class _SpeedDialSectionState extends ConsumerState<SpeedDialSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      (_scrollController.offset - 378).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 378).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final speedDialAsync = ref.watch(speedDialProvider);

    return speedDialAsync.when(
      data: (items) {
        if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Subtitle context + Main Title + Scroll Nav)
                _SpeedDialHeader(
                  subtitle: widget.subtitle,
                  title: widget.title,
                  onScrollLeft: _scrollLeft,
                  onScrollRight: _scrollRight,
                ),
                const SizedBox(height: 8),

                // 2-Row Horizontal Scroll Grid
                SizedBox(
                  height: 254,
                  child: GridView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return SpeedDialCard(
                        item: items[index],
                        size: 116,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SpeedDial2RowGridSkeleton(),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _SpeedDialHeader extends StatelessWidget {
  final String? subtitle;
  final String title;
  final VoidCallback onScrollLeft;
  final VoidCallback onScrollRight;

  const _SpeedDialHeader({
    required this.subtitle,
    required this.title,
    required this.onScrollLeft,
    required this.onScrollRight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            Text(
              subtitle!.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
          ],
          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(UIcons.regular.waveform, size: 18, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReusableHoverIconButton(
                      icon: UIcons.regular.angle_small_left,
                      tooltip: 'Previous',
                      iconSize: 18,
                      onTap: onScrollLeft,
                    ),
                    const SizedBox(width: 4),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.angle_small_right,
                      tooltip: 'Next',
                      iconSize: 18,
                      onTap: onScrollRight,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

