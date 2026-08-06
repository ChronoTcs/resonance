import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/data/models/explore_playlist.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

class ExplorePlaylistCardTile extends ConsumerWidget {
  final ExplorePlaylist playlist;

  const ExplorePlaylistCardTile({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
          onTap: () => _playPlaylist(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: playlist.thumbnailUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(AppIcons.music, color: Colors.grey),
                    ),
                    errorWidget: (c, u, e) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.playlist_play, color: Colors.grey),
                    ),
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
                  tooltip: 'Import to Stream Playlists',
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    try {
      final tracks = await ref
          .read(youtubePlaylistRepositoryProvider)
          .fetchFullPlaylistContents(playlist.id);
      if (context.mounted) Navigator.pop(context);

      if (tracks.isNotEmpty) {
        final mediaItems = tracks
            .map((t) => MediaItem(
                  id: t.id,
                  title: t.title,
                  artist: t.author,
                  thumbnailUrl: t.thumbnailUrl,
                  path: t.id,
                  type: 'audio',
                ))
            .toList();
        await ref.read(audioProvider.notifier).playYouTubeTrack(mediaItems.first);
        if (mediaItems.length > 1) {
          ref.read(audioProvider.notifier).addTracksToQueue(mediaItems.sublist(1));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final tracks = await ref
          .read(youtubePlaylistRepositoryProvider)
          .fetchFullPlaylistContents(playlist.id);
      if (context.mounted) Navigator.pop(context);

      final newId = await ref.read(playlistProvider.notifier).createPlaylist(
            playlist.title,
            isStream: true,
          );
      if (newId != null && tracks.isNotEmpty) {
        final mediaItems = tracks
            .map((t) => MediaItem(
                  id: t.id,
                  title: t.title,
                  artist: t.author,
                  thumbnailUrl: t.thumbnailUrl,
                  path: t.id,
                  type: 'audio',
                ))
            .toList();
        await ref.read(playlistProvider.notifier).addTracksToPlaylist(newId, mediaItems);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist imported to Stream Playlists!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import: $e')),
        );
      }
    }
  }
}
