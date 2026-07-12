import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_detail_screen.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/resonance_button.dart';
import 'package:resonance/core/widgets/resonance_context_menu.dart';
import 'package:resonance/core/widgets/resonance_confirm_dialog.dart';

import 'package:resonance/core/widgets/top_navigation_header.dart';

class PlaylistScreen extends ConsumerWidget {
  final bool isLocalOnly;
  const PlaylistScreen({super.key, this.isLocalOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final selectedId = ref.watch(selectedPlaylistIdProvider);
    final theme = Theme.of(context);

    if (selectedId != null) {
      return PlaylistDetailScreen(playlistId: selectedId);
    }

    if (isLocalOnly) {
      return playlistsAsync.when(
        data: (state) => _buildLocalSection(context, ref, state.local),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            TopNavigationHeader(
              left: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      'Playlists',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(
                    height: 50,
                    width: 260,
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.label,
                      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return theme.primaryColor.withValues(alpha: 0.08);
                        }
                        return null;
                      }),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(UIcons.regular.folder, size: 14),
                              const SizedBox(width: 6),
                              const Text('Local'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(UIcons.regular.world, size: 14),
                              const SizedBox(width: 6),
                              const Text('Stream'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              right: const SizedBox(),
            ),
            Expanded(
              child: playlistsAsync.when(
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
          ],
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
                ResonanceButton(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: AppIcons.add,
                  label: 'New',
                  style: ResonanceButtonStyle.secondary,
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
                    'My Stream Playlists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _importPlaylistDialog(context, ref),
                  icon: Icon(AppIcons.download, size: 20),
                  tooltip: 'Import Playlist',
                ),
                const SizedBox(width: 8),
                ResonanceButton(
                  onPressed: () => _showCreateDialog(context, ref, isStream: true),
                  icon: AppIcons.add,
                  label: 'New',
                  style: ResonanceButtonStyle.secondary,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (playlists.isEmpty)
          _buildEmptyState(
            context, 
            ref, 
            'No stream playlists', 
            'Create or import a playlist to organize online streaming tracks.',
            isOnline: true,
          )
        else
          _buildPlaylistList(playlists),
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
              UIcons.regular.list_music,
              size: 64,
              color: theme.hintColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
            const SizedBox(height: 24),
            ResonanceButton(
              onPressed: () => _showCreateDialog(context, ref, isStream: isOnline),
              icon: AppIcons.add,
              label: isOnline ? 'Create Stream Playlist' : 'Create Local Playlist',
              style: ResonanceButtonStyle.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, {bool isStream = false}) {
    final ctrl = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                controller: ctrl,
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
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    ref.read(playlistProvider.notifier).createPlaylist(v.trim(), isStream: isStream);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ResonanceButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Cancel',
                    style: ResonanceButtonStyle.secondary,
                  ),
                  const SizedBox(width: 12),
                  ResonanceButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        ref
                            .read(playlistProvider.notifier)
                            .createPlaylist(ctrl.text.trim(), isStream: isStream);
                        Navigator.pop(context);
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
      ),
    );
  }

  Future<void> _importPlaylistDialog(BuildContext context, WidgetRef ref) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      
      await ref.read(playlistProvider.notifier).importPlaylist(content);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist imported successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import playlist: $e')),
        );
      }
    }
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
                          placeholder: (c, u) => Container(color: theme.colorScheme.surfaceContainerHighest, child: Icon(AppIcons.music, size: 20)),
                          errorWidget: (c, u, e) => Container(color: theme.colorScheme.surfaceContainerHighest, child: Icon(AppIcons.music, size: 20)),
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
              items: [
                ResonanceContextMenuItem(
                  icon: UIcons.regular.play,
                  label: 'Play all',
                  onTap: () => _playAll(context, ref, playlist),
                ),
                ResonanceContextMenuItem(
                  icon: UIcons.regular.edit,
                  label: 'Rename',
                  onTap: () => _showRenameDialog(context, ref, playlist),
                ),
                if (isOnline)
                  ResonanceContextMenuItem(
                    icon: UIcons.regular.upload,
                    label: 'Export JSON',
                    onTap: () => _exportPlaylist(context, ref, playlist),
                  ),
                ResonanceContextMenuItem(
                  icon: AppIcons.trash,
                  label: 'Delete',
                  isDanger: true,
                  onTap: () => _confirmDelete(context, ref, playlist),
                ),
              ],
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

  Future<void> _exportPlaylist(BuildContext context, WidgetRef ref, Playlist playlist) async {
    try {
      final String? directory = await FilePicker.platform.getDirectoryPath();
      if (directory == null) return;
      
      final jsonString = await ref.read(playlistProvider.notifier).exportPlaylist(playlist.id);
      if (jsonString == null) return;

      final safeName = playlist.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File(p.join(directory, 'playlist_$safeName.json'));
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported to ${p.basename(file.path)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export playlist: $e')),
        );
      }
    }
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) {
    final ctrl = TextEditingController(text: playlist.name);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                'Rename Playlist',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                decoration: InputDecoration(
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
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    ref.read(playlistProvider.notifier).renamePlaylist(playlist.id, v.trim());
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ResonanceButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Cancel',
                    style: ResonanceButtonStyle.secondary,
                  ),
                  const SizedBox(width: 12),
                  ResonanceButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        ref
                            .read(playlistProvider.notifier)
                            .renamePlaylist(playlist.id, ctrl.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    label: 'Save',
                    style: ResonanceButtonStyle.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => ResonanceConfirmDialog(
        title: 'Delete Playlist',
        content: 'Are you sure you want to delete "${playlist.name}"? This cannot be undone.',
        confirmLabel: 'Delete',
        isDanger: true,
        onConfirm: () {
          ref.read(playlistProvider.notifier).deletePlaylist(playlist.id);
        },
      ),
    );
  }
}


