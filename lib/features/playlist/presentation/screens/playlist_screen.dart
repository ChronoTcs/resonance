import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance_app/features/player/application/providers/audio_provider.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import 'package:resonance_app/features/playlist/application/playlist_provider.dart';
import 'package:resonance_app/features/playlist/presentation/screens/playlist_detail_screen.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
// import 'package:resonance_app/core/widgets/hover_widgets.dart'; // Removed

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final selectedId = ref.watch(selectedPlaylistIdProvider);

    if (selectedId != null) {
      // Logic to check if selectedId is online or local
      return PlaylistDetailScreen(playlistId: selectedId);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          toolbarHeight: 0, // Hide main toolbar for custom silver header
          bottom: TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.folder_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Local'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.public_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('YouTube Music'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: playlistsAsync.when(
          data: (state) {
            return TabBarView(
              children: [
                _buildLocalSection(context, ref, state.local),
                _buildOnlineSection(context, ref, state),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildLocalSection(BuildContext context, WidgetRef ref, List<Playlist> playlists) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My Local Playlists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
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
          _buildEmptyState(context, ref, 'No local playlists', 'Create one to organize your files.')
        else
          _buildPlaylistList(playlists),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildOnlineSection(BuildContext context, WidgetRef ref, PlaylistState state) {
    final theme = Theme.of(context);
    final playlists = state.online;
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Liked & Saved Playlists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (state.isLoadingOnline)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    onPressed: () => ref.read(playlistProvider.notifier).refreshOnlinePlaylists(),
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh Online',
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (playlists.isEmpty && !state.isLoadingOnline)
          _buildEmptyState(
            context, 
            ref, 
            'No online playlists', 
            'Login to sync your YouTube Music library.',
            isOnline: true
          )
        else
          _buildPlaylistList(playlists, isOnline: true),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildPlaylistList(List<Playlist> playlists, {bool isOnline = false}) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemCount: playlists.length,
        itemBuilder: (ctx, i) {
          final playlist = playlists[i];
          return _PlaylistTile(playlist: playlist, isOnline: isOnline);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String title, String subtitle, {bool isOnline = false}) {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOnline ? Icons.cloud_off_rounded : Icons.queue_music_rounded,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
            if (!isOnline) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create Local Playlist'),
              ),
            ]
          ],
        ),
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
  const _PlaylistTile({required this.playlist, this.isOnline = false});
  final Playlist playlist;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstTrack = playlist.tracks.isNotEmpty ? playlist.tracks.first : null;

    // Detect if this is an online playlist and needs track loading
    final bool isEmptyOnline = isOnline && playlist.tracks.isEmpty;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ReusableHoverIconButton(
        tooltip: 'Open Playlist',
        padding: 12,
        scaleOnHover: 1.0, // No scale for list tile card
        onTap: () {
          if (isEmptyOnline) {
             ref.read(playlistProvider.notifier).loadOnlinePlaylistTracks(playlist.id);
          }
          ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(playlist.id);
        },
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
                    isEmptyOnline 
                      ? 'Click to sync tracks' 
                      : '${playlist.tracks.length} track${playlist.tracks.length == 1 ? '' : 's'} • ${isOnline ? 'Online' : 'Local'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOnline ? theme.colorScheme.primary : theme.hintColor,
                      fontWeight: isEmptyOnline ? FontWeight.bold : null,
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
                if (isOnline)
                  const PopupMenuItem(
                    value: _PlaylistAction.convertToLocal,
                    child: ListTile(
                      leading: Icon(Icons.download_rounded),
                      title: Text('Convert to Local'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (!isOnline) ...[
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
              ],
            ),
          ],
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
      case _PlaylistAction.convertToLocal:
        ref.read(playlistProvider.notifier).convertOnlineToLocal(playlist);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Converted "${playlist.name}" to local.')),
        );
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

enum _PlaylistAction { play, rename, delete, convertToLocal }
