import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import '../widgets/queue/queue_header_bar.dart';
import '../widgets/queue/queue_item_card.dart';
import '../widgets/queue/queue_now_playing_card.dart';

/// Interactive Unified 3-Tier Queue screen overlay.
///
/// Hierarchy:
/// 1. [QueueHeaderBar]: Top bar with close, total count badge, clear upcoming.
/// 2. [SilkyCustomScrollView] with:
///    - Tier 1: Previously Played (History) - collapsible list of already played tracks.
///    - Tier 2: Now Playing - pinned active track card with equalizer indicator.
///    - Tier 3: Upcoming - drag-and-drop reorderable list with physics slip animation.
class QueueScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const QueueScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isHistoryExpanded = false;
  bool _historyInitialized = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(audioProvider.select((s) => s.currentTrack));
    final queue = ref.watch(audioProvider.select((s) => s.queue));
    final currentIndex = ref.watch(audioProvider.select((s) => s.currentIndex));
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final isCompact = AppBreakpoints.isCompact(context);

    final safeCurrentIndex = currentIndex.clamp(-1, queue.length - 1);

    // Previously played tracks (0 .. currentIndex - 1)
    final previousList = (safeCurrentIndex > 0)
        ? queue.sublist(0, safeCurrentIndex)
        : <MediaItem>[];

    // Upcoming tracks (currentIndex + 1 .. end)
    final upcomingList = (safeCurrentIndex >= 0 && safeCurrentIndex < queue.length - 1)
        ? queue.sublist(safeCurrentIndex + 1)
        : <MediaItem>[];

    // Initialize history expand state (auto-expand if <= 3 tracks, collapse if > 3)
    if (!_historyInitialized && previousList.isNotEmpty) {
      _isHistoryExpanded = previousList.length <= 3;
      _historyInitialized = true;
    }

    final screenWidget = Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background tint
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                color: (isLight ? Colors.white : theme.colorScheme.surface).withValues(alpha: 0.94),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Bar
                QueueHeaderBar(
                  totalUpcoming: upcomingList.length,
                  onClose: () => ref.read(queueOverlayProvider.notifier).setVisible(false),
                  onClearUpcoming: () => ref.read(audioProvider.notifier).clearUpcomingQueue(),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: RawScrollbar(
                      controller: _scrollController,
                      thumbColor: theme.colorScheme.primary.withValues(alpha: 0.45),
                      radius: const Radius.circular(8),
                      thickness: 4,
                      padding: const EdgeInsets.only(right: 2),
                      child: SilkyCustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),

                          // ============================================
                          // 1. PREVIOUSLY PLAYED SECTION (History)
                          // ============================================
                          if (previousList.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            UIcons.regular.rotate_left,
                                            size: 13,
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              isCompact ? 'HISTORY' : 'PREVIOUSLY PLAYED',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: isCompact ? 1.0 : 1.5,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${previousList.length}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ReusableHoverIconButton(
                                      tooltip: _isHistoryExpanded ? 'Hide history' : 'Show history',
                                      padding: 0,
                                      scaleOnHover: 1.05,
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          _isHistoryExpanded = !_isHistoryExpanded;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _isHistoryExpanded ? 'Hide' : 'Show',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              _isHistoryExpanded
                                                  ? UIcons.regular.angle_small_up
                                                  : UIcons.regular.angle_small_down,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isHistoryExpanded)
                              SliverPadding(
                                padding: const EdgeInsets.only(bottom: 12.0, right: 12.0),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final track = previousList[index];
                                      return QueueItemCard(
                                        key: ValueKey('queue_history_${track.id ?? track.path}_$index'),
                                        track: track,
                                        positionTag: '${index + 1}',
                                        index: index,
                                        isHistory: true,
                                        onTap: () {
                                          ref.read(audioProvider.notifier).jumpToQueueIndex(index);
                                        },
                                        onDelete: () {
                                          ref.read(audioProvider.notifier).removeTrackFromQueue(index);
                                        },
                                      );
                                    },
                                    childCount: previousList.length,
                                  ),
                                ),
                              ),
                          ],

                          // ============================================
                          // 2. NOW PLAYING SECTION (Pinned Active)
                          // ============================================
                          if (currentTrack != null) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                child: Text(
                                  'NOW PLAYING',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: QueueNowPlayingCard(track: currentTrack),
                              ),
                            ),
                          ],

                          // ============================================
                          // 3. UPCOMING TRACKS SECTION (Reorderable)
                          // ============================================
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: isCompact
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'UPCOMING',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${upcomingList.length}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              UIcons.regular.menu_burger,
                                              size: 11,
                                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Hold & drag card to reorder',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Text(
                                          'UPCOMING',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${upcomingList.length}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Hold & drag card to reorder',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Upcoming Items List or Empty state
                          if (upcomingList.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 36.0),
                                child: Center(
                                  child: Text(
                                    'No upcoming tracks in queue',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.only(top: 4, bottom: 40, right: 12),
                              sliver: SliverReorderableList(
                                itemCount: upcomingList.length,
                                onReorderItem: (oldIndex, newIndex) {
                                  final realOldIndex = safeCurrentIndex + 1 + oldIndex;
                                  final realNewIndex = safeCurrentIndex + 1 + newIndex;
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
                                  final track = upcomingList[index];
                                  final positionTag = '${index + 1}';
                                  final realIndex = safeCurrentIndex + 1 + index;

                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey('queue_upcoming_${track.id ?? track.path}_$index'),
                                    index: index,
                                    child: QueueItemCard(
                                      track: track,
                                      positionTag: positionTag,
                                      index: index,
                                      isHistory: false,
                                      onTap: () {
                                        ref.read(audioProvider.notifier).jumpToQueueIndex(realIndex);
                                      },
                                      onDelete: () {
                                        ref.read(audioProvider.notifier).removeTrackFromQueue(realIndex);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) return screenWidget;

    return Dismissible(
      key: const ValueKey('queue_screen_dismissible'),
      direction: DismissDirection.down,
      onDismissed: (_) => ref.read(queueOverlayProvider.notifier).setVisible(false),
      child: screenWidget,
    );
  }
}
