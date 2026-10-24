import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/media/media_artwork_widget.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Card item representing a track in the right sidebar playing queue.
/// Supports full horizontal row in expanded mode (310px) and vertical mini-tile
/// in collapsed rail mode (70px).
class QueueSidebarCard extends ConsumerWidget {
  final MediaItem track;
  final int index;
  final bool isPast;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const QueueSidebarCard({
    super.key,
    required this.track,
    required this.index,
    required this.isPast,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(rightSidebarExpandedProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final card = Material(
      color: isCurrent
          ? (isDark ? const Color(0xFF1E222B) : Colors.white)
          : (isDark
              ? const Color(0xFF161920)
              : Colors.black.withValues(alpha: 0.03)),
      borderRadius: BorderRadius.circular(16),
      elevation: isCurrent ? (isDark ? 2 : 3) : 0,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
          context: context,
          ref: ref,
          item: track,
          position: details.globalPosition,
          onRemoveFromQueue: onRemove,
        ),
        borderRadius: BorderRadius.circular(16),
        hoverColor: primary.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : primary.withValues(alpha: 0.25))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Artwork with active waveform badge in minimized mode
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: MediaArtworkWidget(item: track, width: 38, height: 38),
                    ),
                  ),
                  if (isCurrent && !isExpanded)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222B) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          UIcons.regular.waveform_path,
                          size: 11,
                          color: primary,
                        ),
                      ),
                    ),
                ],
              ),

              if (isExpanded) ...[
                const SizedBox(width: 10),

                // Title & Subtitle/Artist with marquee auto-scrolling
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          color: isCurrent
                              ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                              : (isPast
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isPast ? 0.35 : 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right actions: Waveform for active track, or remove button
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      UIcons.regular.waveform_path,
                      size: 16,
                      color: primary,
                    ),
                  )
                else
                  ReusableHoverIconButton(
                    icon: UIcons.regular.cross_small,
                    iconSize: 15,
                    padding: 5,
                    tooltip: 'Remove from Queue',
                    onTap: onRemove,
                  ),

                const SizedBox(width: 2),

                // Explicit Drag Handle with grab cursor
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Icon(
                        UIcons.regular.menu_burger,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: isExpanded
            ? card
            : Tooltip(
                message: '${track.title}\n${track.artist ?? 'Unknown Artist'}',
                preferBelow: false,
                child: card,
              ),
      ),
    );
  }
}
