import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/media/media_artwork_widget.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Card item representing a recommended track in the right companion sidebar.
/// Supports full horizontal row in expanded mode (310px) and vertical mini-tile
/// in collapsed rail mode (70px).
class RecommendationSidebarCard extends ConsumerWidget {
  final MediaItem track;
  final VoidCallback onTap;
  final VoidCallback onMoreActions;

  const RecommendationSidebarCard({
    super.key,
    required this.track,
    required this.onTap,
    required this.onMoreActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(rightSidebarExpandedProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final card = Material(
      color: isDark
          ? const Color(0xFF1E222B).withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 1 : 2,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
          context: context,
          ref: ref,
          item: track,
          position: details.globalPosition,
        ),
        onLongPress: () => MediaActionUtils.showMediaActions(
          context: context,
          ref: ref,
          item: track,
        ),
        borderRadius: BorderRadius.circular(16),
        hoverColor: primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.03),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Rounded Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: MediaArtworkWidget(item: track, width: 38, height: 38),
                ),
              ),

              if (isExpanded) ...[
                const SizedBox(width: 10),

                // Title & Artist with marquee auto-scrolling
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
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions menu button using app standard ReusableHoverIconButton
                ReusableHoverIconButton(
                  icon: UIcons.regular.menu_dots,
                  iconSize: 15,
                  padding: 5,
                  tooltip: 'Actions',
                  onTap: onMoreActions,
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
