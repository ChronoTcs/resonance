import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/home/presentation/widgets/quick_picks_track_tile.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';

/// Horizontal snap carousel of 4-item vertical columns matching Picture 3 ("Quick picks").
///
/// Features:
/// - Header with "Quick picks" on left and "Play all" pill button on right with < > paging arrows.
/// - Horizontal PageView where each page contains exactly 4 stacked QuickPicksTrackTile items.
/// - Next column peeks in from the right (viewportFraction: 0.88 on mobile, responsive on desktop).
/// - "Play all" queues and plays all tracks sequentially.
class QuickPicksColumnSection extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;

  const QuickPicksColumnSection({
    super.key,
    this.title = 'Quick picks',
    this.subtitle,
  });

  @override
  ConsumerState<QuickPicksColumnSection> createState() =>
      _QuickPicksColumnSectionState();
}

class _QuickPicksColumnSectionState
    extends ConsumerState<QuickPicksColumnSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _previousPage() {
    final isDesktop = AppBreakpoints.isWide(context);
    final columnWidth = isDesktop ? 340.0 : (MediaQuery.sizeOf(context).width * 0.85).clamp(280.0, 360.0);
    final scrollAmount = columnWidth + 14;

    _scrollController.animateTo(
      (_scrollController.offset - scrollAmount).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextPage() {
    final isDesktop = AppBreakpoints.isWide(context);
    final columnWidth = isDesktop ? 340.0 : (MediaQuery.sizeOf(context).width * 0.85).clamp(280.0, 360.0);
    final scrollAmount = columnWidth + 14;

    _scrollController.animateTo(
      (_scrollController.offset + scrollAmount).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(quickPicksProvider);

    return asyncData.when(
      data: (items) {
        if (items.isEmpty) {
          final isOnline = ref.watch(
            networkConnectivityProvider.select((s) => s.isOnline),
          );
          if (!isOnline) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // Chunk items into columns of 4
        final List<List<MediaItem>> columns = [];
        for (var i = 0; i < items.length; i += 4) {
          columns.add(items.sublist(i, (i + 4).clamp(0, items.length)));
        }

        final isDesktop = AppBreakpoints.isWide(context);
        final columnWidth = isDesktop ? 340.0 : (MediaQuery.sizeOf(context).width * 0.85).clamp(280.0, 360.0);

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuickPicksHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  onPlayAll: () {
                    if (items.isNotEmpty) {
                      ref
                          .read(queueOrchestratorProvider)
                          .playSequentialContext(items.first, items);
                    }
                  },
                  onPrevious: _previousPage,
                  onNext: _nextPage,
                ),
                const SizedBox(height: 8),

                // Horizontal snapping multi-row carousel
                SizedBox(
                  height: 256,
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: columns.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, colIndex) {
                      return _QuickPicksColumn(
                        items: columns[colIndex],
                        allItems: items,
                        columnWidth: columnWidth,
                        onTrackTap: (item) {
                          ref
                              .read(queueOrchestratorProvider)
                              .playSequentialContext(item, items);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );

      },
      loading: () => const QuickPicksColumnCarouselSkeleton(),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _QuickPicksHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onPlayAll;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _QuickPicksHeader({
    required this.title,
    this.subtitle,
    required this.onPlayAll,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(UIcons.regular.music, size: 18, color: theme.primaryColor),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ResonanceButton(
                  onPressed: onPlayAll,
                  icon: UIcons.regular.play,
                  label: 'Play all',
                  style: ResonanceButtonStyle.secondary,
                ),
                const SizedBox(width: 8),
                ReusableHoverIconButton(
                  icon: UIcons.regular.angle_small_left,
                  tooltip: 'Previous',
                  iconSize: 18,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 4),
                ReusableHoverIconButton(
                  icon: UIcons.regular.angle_small_right,
                  tooltip: 'Next',
                  iconSize: 18,
                  onTap: onNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPicksColumn extends StatelessWidget {
  final List<MediaItem> items;
  final List<MediaItem> allItems;
  final double columnWidth;
  final void Function(MediaItem item) onTrackTap;

  const _QuickPicksColumn({
    required this.items,
    required this.allItems,
    required this.columnWidth,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columnWidth,
      child: Column(
        children: items.map((item) {
          return Expanded(
            child: QuickPicksTrackTile(
              item: item,
              onTap: () => onTrackTap(item),
            ),
          );
        }).toList(),
      ),
    );
  }
}
