import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../features/library/data/models/media_item.dart';
import '../../features/playlist/application/playlist_provider.dart';
import '../../features/download/application/providers/download_provider.dart';
import '../../features/download/data/models/download_item.dart';
import '../../core/providers/navigation_provider.dart';

class MediaActionsBottomSheet extends ConsumerWidget {
  const MediaActionsBottomSheet({
    super.key,
    required this.item,
    this.playlistId, // If provided, show "Remove from playlist" instead of "Add to"
    this.onDelete, // If provided, show a delete/permanent remove option
    this.video, // Optional pre-fetched metadata for downloads
  });

  final MediaItem item;
  final String? playlistId;
  final VoidCallback? onDelete;
  final yt.Video? video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOnline = item.id != null;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Info Header
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
            child: item.albumArt != null
                ? Image.memory(
                    item.albumArt!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : (item.thumbnailUrl != null)
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                        errorWidget: (c, u, e) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          isOnline ? Icons.public : Icons.music_note,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
            ),
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(item.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(),
          
          // Action: Add to Playlist
          if (playlistId == null)
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _showPlaylistPicker(context);
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded, color: Colors.red),
              title: const Text('Remove from this playlist', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(playlistProvider.notifier).removeTrackFromPlaylist(playlistId!, item.id ?? item.path);
                Navigator.pop(context);
              },
            ),

          // Action: Download (Online only)
          if (isOnline)
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download to library'),
              onTap: () {
                // 1. Add to download queue
                ref.read(downloadProvider.notifier).addToQueue(
                  [item.id!],
                  type: DownloadType.audio,
                  source: DownloadSource.ytmusic,
                  video: video, // Metadata Passthrough
                );
                
                // 2. Switch to download tab
                Navigator.pop(context); // Close bottom sheet
                ref.read(mainNavigationProvider.notifier).setIndex(4); // 4 is the Download tab index
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Started download: ${item.title}')),
                );
              },
            ),

          // Action: View Details
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Song details'),
            onTap: () {
              Navigator.pop(context);
              _showDetailsDialog(context);
            },
          ),
          
          // Action: Delete (passed from local library, etc)
          if (onDelete != null)
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Delete from device', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showPlaylistPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final playlistsAsync = ref.watch(playlistProvider);
          return playlistsAsync.when(
            data: (state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Select Playlist'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                  ],
                ),
                // Action: Create New Playlist
                ListTile(
                  leading: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                  title: Text('Create New Playlist', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(context);
                  },
                ),
                const Divider(height: 1),
                if (state.local.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No local playlists found.'),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.local.length,
                      itemBuilder: (ctx, i) {
                        final pl = state.local[i];
                        return ListTile(
                          leading: const Icon(Icons.queue_music_rounded),
                          title: Text(pl.name),
                          onTap: () {
                            final messenger = ScaffoldMessenger.of(ctx);
                            ref.read(playlistProvider.notifier).addTrackToPlaylist(pl.id, item);
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Added to ${pl.name}')),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) => AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter playlist name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(ctx);
                  // 1. Create the playlist
                  await ref.read(playlistProvider.notifier).createPlaylist(name);
                  
                  // 2. Get the new playlist ID from local list
                  final stateObj = await ref.read(playlistProvider.future);
                  final newPl = stateObj.local.firstWhere((p) => p.name == name);
                  
                  // 3. Add the track to it
                  await ref.read(playlistProvider.notifier).addTrackToPlaylist(newPl.id, item);
                  
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Created "$name" and added song.')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Metadata Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Title', item.title),
            _detailRow('Artist', item.artist ?? '-'),
            _detailRow('Album', item.album ?? '-'),
            _detailRow('Path/ID', item.id ?? item.path),
            _detailRow('Type', item.type),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
