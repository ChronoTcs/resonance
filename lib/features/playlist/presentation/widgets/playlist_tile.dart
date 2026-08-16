import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';

import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/application/playlist_io_helper.dart';

class PlaylistTile extends ConsumerWidget {
  const PlaylistTile({super.key, required this.playlist, this.isOnline = false});
  final Playlist playlist;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bool isLiked = playlist.name == 'Liked Songs';
    final firstTrack = playlist.tracks.isNotEmpty ? playlist.tracks.first : null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: 'Open Playlist',
        waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(playlist.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail / Liked Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isLiked
                      ? Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            UIcons.solid.heart,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        )
                      : firstTrack != null
                          ? MediaArtworkWidget(
                              item: firstTrack,
                              width: 56,
                              height: 56,
                              borderRadius: 8,
                              placeholderIcon: AppIcons.playlist,
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                AppIcons.playlist,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${playlist.tracks.length} track${playlist.tracks.length == 1 ? '' : 's'} • ${isOnline ? 'Stream' : 'Local'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isOnline ? theme.colorScheme.primary : theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Context Menu Button (single 8px rounded hover layer)
                ResonanceContextMenu(
                  icon: AppIcons.moreVert,
                  iconSize: 16,
                  tooltip: 'More options',
                  items: PlaylistIOHelper.buildPlaylistMenuItems(
                    context: context,
                    ref: ref,
                    playlist: playlist,
                    isOnline: isOnline,
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
