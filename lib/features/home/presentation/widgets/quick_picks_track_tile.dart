import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Standalone list tile for Quick Picks row items matching Picture 3.
///
/// Features:
/// - 52x52 dp rounded thumbnail.
/// - Single-line bold title.
/// - Subtitle with optional [E] explicit badge, artist name, bullet separator, and play count/duration.
/// - 3-dots vertical action menu trailing.
class QuickPicksTrackTile extends ConsumerWidget {
  final MediaItem item;
  final String? subtitleInfo;
  final bool isExplicit;
  final VoidCallback? onTap;

  const QuickPicksTrackTile({
    super.key,
    required this.item,
    this.subtitleInfo,
    this.isExplicit = false,
    this.onTap,
  });

  void _handleTap(WidgetRef ref) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (item.isLocal ||
        (item.path.isNotEmpty && !item.isStreaming && !item.path.startsWith('http'))) {
      ref.read(audioProvider.notifier).playTrack(item);
    } else {
      ref.read(audioProvider.notifier).playYouTubeTrack(item);
    }
  }

  Widget _buildThumbnail(ThemeData theme) {
    final localArtPath =
        (item.thumbnailUrl != null && !item.thumbnailUrl!.startsWith('http'))
            ? item.thumbnailUrl
            : null;

    Widget img;
    if (localArtPath != null && File(localArtPath).existsSync()) {
      img = Image.file(
        File(localArtPath),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(theme),
      );
    } else if (item.thumbnailUrl != null && item.thumbnailUrl!.startsWith('http')) {
      img = CachedNetworkImage(
        imageUrl: item.thumbnailUrl!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, _) => _buildPlaceholder(theme),
        errorWidget: (_, _, _) => _buildPlaceholder(theme),
      );
    } else {
      img = _buildPlaceholder(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: img,
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 52,
      height: 52,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(AppIcons.music, size: 22, color: Colors.grey),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null || duration == Duration.zero) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artist = item.artist ?? 'Unknown Artist';
    final durationStr = _formatDuration(item.duration);
    final secondary = subtitleInfo ?? (durationStr.isNotEmpty ? '$artist • $durationStr' : artist);

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: () => _handleTap(ref),
      onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
        context: context,
        ref: ref,
        item: item,
        position: details.globalPosition,
      ),
      onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
        child: Row(
          children: [
            // 1. Thumbnail
            _buildThumbnail(theme),
            const SizedBox(width: 12),

            // 2. Track Title & Artist Subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isExplicit) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Overflow Action Menu
            OverflowMenuButton(
              tooltip: 'Actions',
              onTap: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: item),
            ),
          ],
        ),
      ),
    );
  }
}
