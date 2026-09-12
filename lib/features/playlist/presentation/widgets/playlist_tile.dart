import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';

import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/presentation/widgets/playlist_actions_bottom_sheet.dart';

class PlaylistTile extends ConsumerWidget {
  const PlaylistTile({super.key, required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(playlist.id);
          },
          onSecondaryTapDown: (details) => PlaylistActionsBottomSheet.showPlaylistMenu(
            context: context,
            ref: ref,
            playlist: playlist,
            position: details.globalPosition,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _PlaylistTileArtwork(
                  isLiked: isLiked,
                  firstTrack: firstTrack,
                ),
                const SizedBox(width: 12),
                _PlaylistTileInfo(
                  title: playlist.name,
                  subtitle: _buildSubtitle(playlist),
                ),
                OverflowMenuButton(
                  tooltip: 'More options',
                  onTap: () => PlaylistActionsBottomSheet.show(
                    context: context,
                    ref: ref,
                    playlist: playlist,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(Playlist p) {
    final count = p.tracks.length;
    final countStr = '$count track${count == 1 ? '' : 's'}';
    if (count == 0) return countStr;
    final hasLocal = p.tracks.any((t) => !t.isStreaming);
    final hasStream = p.tracks.any((t) => t.isStreaming);
    if (hasLocal && hasStream) return '$countStr • Mixed';
    if (hasStream) return '$countStr • Stream';
    return '$countStr • Local';
  }
}

class _PlaylistTileArtwork extends StatelessWidget {
  final bool isLiked;
  final dynamic firstTrack;

  const _PlaylistTileArtwork({
    required this.isLiked,
    required this.firstTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
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
                  placeholderIcon: UIcons.regular.list_music,
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    UIcons.regular.list_music,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
    );
  }
}

class _PlaylistTileInfo extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaylistTileInfo({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}
