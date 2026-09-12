import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'queue_item_card.dart';

/// Reorderable Queue list utilizing the [SilkyCustomScrollView] system.
/// Features kinetic silky smooth scrolling, slip animation physics, hold-to-drag
/// (mouse hold-click on Windows and touch hold on Android), and an elegantly placed
/// scrollbar that runs in its own dedicated gutter without overlapping cards.
class ReorderableQueueList extends ConsumerStatefulWidget {
  final List<MediaItem> upcomingTracks;
  final int currentIndex;

  const ReorderableQueueList({
    super.key,
    required this.upcomingTracks,
    required this.currentIndex,
  });

  @override
  ConsumerState<ReorderableQueueList> createState() => _ReorderableQueueListState();
}

class _ReorderableQueueListState extends ConsumerState<ReorderableQueueList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RawScrollbar(
      controller: _scrollController,
      thumbColor: theme.colorScheme.primary.withValues(alpha: 0.45),
      radius: const Radius.circular(8),
      thickness: 4,
      padding: const EdgeInsets.only(right: 2),
      child: SilkyCustomScrollView(
        controller: _scrollController,
        slivers: [
          // 12px right padding creates dedicated gutter so scrollbar never touches/overlaps cards
          SliverPadding(
            padding: const EdgeInsets.only(top: 4, bottom: 40, right: 12),
            sliver: SliverReorderableList(
              itemCount: widget.upcomingTracks.length,
              onReorderItem: (oldIndex, newIndex) {
                final realOldIndex = widget.currentIndex + 1 + oldIndex;
                final realNewIndex = widget.currentIndex + 1 + newIndex;
                ref.read(audioProvider.notifier).reorderQueue(realOldIndex, realNewIndex);
              },
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final double animValue = Curves.easeOutCubic.transform(animation.value);
                    final double elevation = lerpDouble(0, 16, animValue)!;
                    final double scale = lerpDouble(1.0, 1.03, animValue)!;

                    return Transform.scale(
                      scale: scale,
                      child: Material(
                        color: Colors.transparent,
                        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                        elevation: elevation,
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final track = widget.upcomingTracks[index];
                final positionTag = 'N+${index + 1}';

                return ReorderableDelayedDragStartListener(
                  key: ValueKey('queue_item_${track.id ?? track.path}_$index'),
                  index: index,
                  child: QueueItemCard(
                    track: track,
                    positionTag: positionTag,
                    index: index,
                    onTap: () {
                      final targetIndex = widget.currentIndex + 1 + index;
                      ref.read(audioProvider.notifier).jumpToQueueIndex(targetIndex);
                    },
                    onDelete: () {
                      final targetIndex = widget.currentIndex + 1 + index;
                      ref.read(audioProvider.notifier).removeTrackFromQueue(targetIndex);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
