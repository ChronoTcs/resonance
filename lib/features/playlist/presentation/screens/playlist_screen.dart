import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance_app/features/player/data/repositories/audio_provider.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import 'package:resonance_app/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:resonance_app/features/playlist/presentation/screens/playlist_detail_screen.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: playlistsAsync.when(
        data: (playlists) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My Playlists',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showCreateDialog(context, ref),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (playlists.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 72,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No playlists yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create one to organise your music',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showCreateDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Playlist'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: playlists.length,
                    itemBuilder: (ctx, i) {
                      final playlist = playlists[i];
                      return _PlaylistTile(playlist: playlist);
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref.read(playlistProvider.notifier).createPlaylist(v.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(playlistProvider.notifier)
                    .createPlaylist(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
class _PlaylistTile extends ConsumerWidget {
  const _PlaylistTile({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Resolve first track art
    final firstTrack = playlist.tracks.isNotEmpty ? playlist.tracks.first : null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: firstTrack?.albumArt != null
                    ? Image.memory(
                        firstTrack!.albumArt!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : (firstTrack?.thumbnailUrl != null)
                        ? CachedNetworkImage(
                            imageUrl: firstTrack!.thumbnailUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 20)),
                            errorWidget: (c, u, e) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 20)),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.queue_music,
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
                      '${playlist.tracks.length} track${playlist.tracks.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Context menu
              PopupMenuButton<_PlaylistAction>(
                onSelected: (action) =>
                    _handleAction(context, ref, action, playlist),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _PlaylistAction.play,
                    child: ListTile(
                      leading: Icon(Icons.play_arrow_rounded),
                      title: Text('Play all'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _PlaylistAction.rename,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Rename'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _PlaylistAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    _PlaylistAction action,
    Playlist playlist,
  ) {
    switch (action) {
      case _PlaylistAction.play:
        _playAll(context, ref, playlist);
        break;
      case _PlaylistAction.rename:
        _showRenameDialog(context, ref, playlist);
        break;
      case _PlaylistAction.delete:
        _confirmDelete(context, ref, playlist);
        break;
    }
  }

  void _playAll(BuildContext context, WidgetRef ref, Playlist playlist) {
    if (playlist.tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This playlist has no tracks')),
      );
      return;
    }
    final first = playlist.tracks.first;
    ref.read(audioProvider.notifier).playTrack(first);
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(playlistProvider.notifier)
                    .renamePlaylist(playlist.id, ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(playlistProvider.notifier).deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

enum _PlaylistAction { play, rename, delete }
