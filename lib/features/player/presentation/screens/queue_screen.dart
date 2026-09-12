import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import '../widgets/queue/queue_header_bar.dart';
import '../widgets/queue/queue_now_playing_card.dart';
import '../widgets/queue/reorderable_queue_list.dart';

/// Interactive Queue screen overlay.
/// Composed of modular, decoupled components:
/// - [QueueHeaderBar]: Close, buffer size pill selector, count badge, clear.
/// - [QueueNowPlayingCard]: Pinned active track with visualizer indicator.
/// - [ReorderableQueueList]: Drag-and-drop list with physics slip animation and hold support.
class QueueScreen extends ConsumerWidget {
  final bool isEmbedded;

  const QueueScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final currentTrack = audioState.currentTrack;
    final queue = audioState.queue;
    final currentIndex = audioState.currentIndex;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final isCompact = AppBreakpoints.isCompact(context);

    // Upcoming tracks start strictly after currentIndex
    final upcomingList = (currentIndex >= 0 && currentIndex < queue.length - 1)
        ? queue.sublist(currentIndex + 1)
        : <MediaItem>[];

    final screenWidget = Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background blur and tint
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: (isLight ? Colors.white : Colors.black).withValues(alpha: 0.65),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Pinned Currently Playing Card
                        if (currentTrack != null)
                          QueueNowPlayingCard(track: currentTrack),

                        const SizedBox(height: 16),

                        // Upcoming Tracks Header
                        if (isCompact) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                          ),
                        ] else ...[
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
                        ],
                        const SizedBox(height: 8),

                        // Draggable / Reorderable Upcoming Tracks List
                        Expanded(
                          child: upcomingList.isEmpty
                              ? Center(
                                  child: Text(
                                    'No upcoming tracks in queue',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                )
                              : ReorderableQueueList(
                                  upcomingTracks: upcomingList,
                                  currentIndex: currentIndex,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isEmbedded) return screenWidget;

    return Dismissible(
      key: const ValueKey('queue_screen_dismissible'),
      direction: DismissDirection.down,
      onDismissed: (_) => ref.read(queueOverlayProvider.notifier).setVisible(false),
      child: screenWidget,
    );
  }
}
