import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/app_icons.dart';

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
    final firstTrack = playlist.tracks.isNotEmpty ? playlist.tracks.first : null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ReusableHoverIconButton(
        tooltip: 'Open Playlist',
        padding: 12,
        scaleOnHover: 1.0, // No scale for list tile card
        onTap: () {
          ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(playlist.id);
        },
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: firstTrack != null
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
            // Context menu
            ResonanceContextMenu(
              items: PlaylistIOHelper.buildPlaylistMenuItems(
                context: context,
                ref: ref,
                playlist: playlist,
                isOnline: isOnline,
              ),
              child: ReusableHoverIconButton(
                icon: AppIcons.moreVert,
                tooltip: 'More options',
                iconSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
