import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/data/models/explore_playlist.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

class ExplorePlaylistCardTile extends ConsumerWidget {
  final ExplorePlaylist playlist;

  const ExplorePlaylistCardTile({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaItem = MediaItem(
      id: playlist.id,
      title: playlist.title,
      artist: playlist.author,
      thumbnailUrl: playlist.thumbnailUrl,
      path: playlist.id,
      type: 'playlist',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
        ),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () => _playPlaylist(context, ref),
          onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
            context: context,
            ref: ref,
            item: mediaItem,
            position: details.globalPosition,
          ),
          onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: mediaItem),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ThumbnailUtils.toCardResolution(playlist.thumbnailUrl),
                    width: 80,
                    height: 80,
                    memCacheWidth: 400,
                    memCacheHeight: 400,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(AppIcons.music, color: Colors.grey),
                    ),
                    errorWidget: (c, u, e) {
                      final fallbackUrl = ThumbnailUtils.getFallbackResolution(u);
                      if (fallbackUrl != null && fallbackUrl != u) {
                        return CachedNetworkImage(
                          imageUrl: ThumbnailUtils.toCardResolution(fallbackUrl),
                          width: 80,
                          height: 80,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          fit: BoxFit.cover,
                          placeholder: (c2, u2) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(AppIcons.music, color: Colors.grey),
                          ),
                          errorWidget: (c2, u2, e2) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.playlist_play, color: Colors.grey),
                          ),
                        );
                      }
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.playlist_play, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playlist.author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ReusableHoverIconButton(
                  icon: Icons.playlist_add,
                  tooltip: 'Save to Playlists',
                  iconSize: 20,
                  onTap: () => _importPlaylist(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playPlaylist(BuildContext context, WidgetRef ref) async {
    final mediaItem = MediaItem(
      id: playlist.id,
      title: playlist.title,
      artist: playlist.author,
      thumbnailUrl: playlist.thumbnailUrl,
      path: playlist.id,
      type: 'playlist',
    );
    await MediaActionUtils.playOnlinePlaylist(context, ref, mediaItem);
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref) async {
    final mediaItem = MediaItem(
      id: playlist.id,
      title: playlist.title,
      artist: playlist.author,
      thumbnailUrl: playlist.thumbnailUrl,
      path: playlist.id,
      type: 'playlist',
    );
    await MediaActionUtils.saveOnlinePlaylist(context, ref, mediaItem);
  }
}
