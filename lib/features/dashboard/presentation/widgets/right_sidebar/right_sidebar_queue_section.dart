import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/common/loading_skeletons.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/queue_sidebar_card.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

/// Playing Queue section for the right sidebar with drag-and-drop reordering.
/// Adapts gracefully between expanded panel (310px) and collapsed rail (70px).
class RightSidebarQueueSection extends ConsumerStatefulWidget {
  const RightSidebarQueueSection({super.key});

  @override
  ConsumerState<RightSidebarQueueSection> createState() => _RightSidebarQueueSectionState();
}

class _RightSidebarQueueSectionState extends ConsumerState<RightSidebarQueueSection> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrolledIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveIndex(int activeIndex, bool isExpanded) {
    if (activeIndex < 0 || activeIndex == _lastScrolledIndex || !_scrollController.hasClients) {
      return;
    }
    _lastScrolledIndex = activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const itemHeight = 62.0;
      final targetOffset = (activeIndex * itemHeight) - 80.0;
      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(rightSidebarExpandedProvider);
    final queue = ref.watch(audioProvider.select((s) => s.queue));
    final currentIndex = ref.watch(audioProvider.select((s) => s.currentIndex));
    final isShuffle = ref.watch(audioProvider.select((s) => s.isShuffleEnabled));
    final isLoading = ref.watch(audioProvider.select((s) => s.isLoading));

    if (currentIndex != _lastScrolledIndex) {
      _scrollToActiveIndex(currentIndex, isExpanded);
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (Adapts between full controls and compact "Queue" badge)
        SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: isExpanded
              ? Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Playing Queue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${queue.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Shuffle button using ReusableHoverIconButton
                    ReusableHoverIconButton(
                      icon: UIcons.regular.shuffle,
                      iconSize: 16,
                      padding: 6,
                      tooltip: isShuffle ? 'Shuffle On' : 'Shuffle Off',
                      iconColor: isShuffle ? primary : null,
                      onTap: () => ref.read(audioProvider.notifier).toggleShuffle(),
                    ),
                    // Clear queue button using ReusableHoverIconButton
                    ReusableHoverIconButton(
                      icon: UIcons.regular.trash,
                      iconSize: 16,
                      padding: 6,
                      tooltip: 'Clear Upcoming Queue',
                      onTap: () => ref.read(audioProvider.notifier).clearUpcomingQueue(),
                    ),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: 'Playing Queue (${queue.length})',
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Queue',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${queue.length}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),
        ),

        // List / Skeleton / Empty state
        Expanded(
          child: isLoading && queue.isEmpty
              ? RightSidebarListSkeleton(isExpanded: isExpanded)
              : (queue.isEmpty
                  ? (isExpanded
                      ? _buildEmptyQueue(context)
                      : Center(
                          child: Tooltip(
                            message: 'Queue is empty',
                            child: Icon(
                              UIcons.regular.list_music,
                              size: 22,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ))
                  : SilkyScroll(
                      controller: _scrollController,
                      builder: (context, controller, physics, pointerDeviceKind) {
                        return ReorderableListView.builder(
                          scrollController: controller,
                          physics: physics,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          itemCount: queue.length,
                          itemExtent: 62.0,
                          buildDefaultDragHandles: false,
                          onReorderItem: (int oldIndex, int newIndex) {
                            ref.read(audioProvider.notifier).reorderQueue(oldIndex, newIndex);
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
                                    shadowColor: primary.withValues(alpha: 0.35),
                                    elevation: elevation,
                                    borderRadius: BorderRadius.circular(16),
                                    child: child,
                                  ),
                                );
                              },
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final track = queue[index];
                            final isPast = index < currentIndex;
                            final isCurrent = index == currentIndex;

                            return ReorderableDelayedDragStartListener(
                              key: ValueKey('queue_sidebar_item_${track.id ?? track.path}_$index'),
                              index: index,
                              child: QueueSidebarCard(
                                track: track,
                                index: index,
                                isPast: isPast,
                                isCurrent: isCurrent,
                                onTap: () => ref.read(audioProvider.notifier).jumpToQueueIndex(index),
                                onRemove: () => ref.read(audioProvider.notifier).removeTrackFromQueue(index),
                              ),
                            );
                          },
                        );
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildEmptyQueue(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            UIcons.regular.list_music,
            size: 32,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Queue is empty',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Play a track or add from recommendations',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
