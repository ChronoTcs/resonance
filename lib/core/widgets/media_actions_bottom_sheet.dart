import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../features/library/data/models/media_item.dart';
import '../../features/playlist/application/playlist_provider.dart';
import '../../features/download/application/providers/download_provider.dart';
import '../../features/download/data/models/download_item.dart';
import '../../core/providers/navigation_provider.dart';
import 'package:resonance/core/widgets/resonance_button.dart';

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
    final isOnline = item.isStreaming;

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
                        placeholder: (c, u) => Container(color: theme.colorScheme.surfaceContainerHighest, child: Icon(AppIcons.music)),
                        errorWidget: (c, u, e) => Container(color: theme.colorScheme.surfaceContainerHighest, child: Icon(AppIcons.music)),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          isOnline ? UIcons.regular.world : AppIcons.music,
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
              leading: Icon(AppIcons.add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _showPlaylistPicker(context);
              },
            )
          else
            ListTile(
              leading: Icon(AppIcons.close, color: Colors.red),
              title: const Text('Remove from this playlist', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(playlistProvider.notifier).removeTrackFromPlaylist(playlistId!, item.id ?? item.path);
                Navigator.pop(context);
              },
            ),

          // Action: Download (Online only)
          if (isOnline)
            ListTile(
              leading: Icon(AppIcons.download),
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
            leading: Icon(UIcons.regular.info),
            title: const Text('Song details'),
            onTap: () {
              Navigator.pop(context);
              _showDetailsDialog(context);
            },
          ),
          
          // Action: Delete (passed from local library, etc)
          if (onDelete != null)
            ListTile(
              leading: Icon(AppIcons.trash, color: Colors.red),
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
          final showOnline = item.isStreaming;

          return playlistsAsync.when(
            data: (state) {
              final targetList = showOnline ? state.online : state.local;
              final emptyMsg = showOnline ? 'No stream playlists found.' : 'No local playlists found.';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Select Playlist'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(AppIcons.close))
                    ],
                  ),
                  ListTile(
                    leading: Icon(AppIcons.add, color: theme.colorScheme.primary),
                    title: Text('Create New Playlist', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(context);
                    },
                  ),
                  const Divider(height: 1),
                  if (targetList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(emptyMsg),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: targetList.length,
                        itemBuilder: (ctx, i) {
                          final pl = targetList[i];
                          return ListTile(
                            leading: Icon(AppIcons.playlist),
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
              );
            },
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
        builder: (ctx, ref, _) {
          final theme = Theme.of(ctx);
          final isStream = item.isStreaming;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStream ? 'New Stream Playlist' : 'New Local Playlist',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Playlist name',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ResonanceButton(
                        onPressed: () => Navigator.pop(ctx),
                        label: 'Cancel',
                        style: ResonanceButtonStyle.secondary,
                      ),
                      const SizedBox(width: 12),
                      ResonanceButton(
                        onPressed: () async {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            final messenger = ScaffoldMessenger.of(ctx);
                            // 1. Create the playlist
                            await ref.read(playlistProvider.notifier).createPlaylist(name, isStream: isStream);
                            
                            // 2. Get the new playlist ID from correct list
                            final stateObj = await ref.read(playlistProvider.future);
                            final targetList = isStream ? stateObj.online : stateObj.local;
                            final newPl = targetList.firstWhere((p) => p.name == name);
                            
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
                        label: 'Create',
                        style: ResonanceButtonStyle.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
