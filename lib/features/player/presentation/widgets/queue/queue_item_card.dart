import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/media/media_artwork_widget.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Individual draggable Queue item card.
/// Features clean typography, media artwork, position badge, remove action,
/// and an explicit instant drag handle with grab cursor feedback.
class QueueItemCard extends ConsumerWidget {
  final MediaItem track;
  final String positionTag;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const QueueItemCard({
    super.key,
    required this.track,
    required this.positionTag,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
            context: context,
            ref: ref,
            item: track,
            position: details.globalPosition,
            onRemoveFromQueue: onDelete,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Position Index (1, 2, 3, etc.)
                Container(
                  width: 28,
                  alignment: Alignment.center,
                  child: Text(
                    positionTag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: MediaArtworkWidget(item: track),
                  ),
                ),
                const SizedBox(width: 12),

                // Title and artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist ?? 'Unknown Artist',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Remove button
                ReusableHoverIconButton(
                  icon: UIcons.regular.cross_small,
                  tooltip: 'Remove',
                  iconSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                  onTap: onDelete,
                ),

                // Instant Drag Handle (zero delay drag on the handle with grab cursor)
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Icon(
                        UIcons.regular.menu_burger,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
