import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

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
            leading: MediaArtworkWidget(
              item: item,
              width: 48,
              height: 48,
              borderRadius: 8,
              placeholderIcon: isOnline ? UIcons.regular.world : AppIcons.music,
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),

          // Action: Add to Playlist
          if (playlistId == null)
            ListTile(
              leading: Icon(AppIcons.add),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                showPlaylistPicker(context, item);
              },
            )
          else
            ListTile(
              leading: Icon(AppIcons.close, color: Colors.red),
              title: const Text(
                'Remove from this playlist',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                ref
                    .read(playlistProvider.notifier)
                    .removeTrackFromPlaylist(playlistId!, item.id ?? item.path);
                Navigator.pop(context);
              },
            ),

          // Action: Download (Online only & not already in library)
          if (isOnline && !ref.watch(libraryProvider).isTrackDownloaded(item.id, title: item.title, artist: item.artist))
            ListTile(
              leading: Icon(AppIcons.download),
              title: const Text('Download to library'),
              onTap: () {
                // 1. Add to download queue
                ref
                    .read(downloadProvider.notifier)
                    .addToQueue(
                      [item.id!],
                      type: DownloadType.audio,
                      source: DownloadSource.ytmusic,
                      video: video, // Metadata Passthrough
                    );

                // 2. Close bottom sheet & trigger notification
                Navigator.pop(context);
                ref
                    .read(notificationProvider.notifier)
                    .showNotification(
                      'Download Started',
                      'Downloading "${item.title}" to library...',
                      target: 'target:download',
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
              title: const Text(
                'Delete from device',
                style: TextStyle(color: Colors.red),
              ),
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

  static void showPlaylistPicker(BuildContext context, MediaItem item) {
    final showOnline = item.isStreaming;
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final playlistsAsync = ref.watch(playlistProvider);

          return playlistsAsync.when(
            data: (state) {
              final targetList = showOnline ? state.online : state.local;
              final emptyMsg = showOnline
                  ? 'No stream playlists found.'
                  : 'No local playlists found.';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Select Playlist'),
                    automaticallyImplyLeading: false,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ReusableHoverIconButton(
                          icon: UIcons.regular.cross,
                          tooltip: 'Close',
                          iconSize: 16.0,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  ListTile(
                    leading: Icon(
                      AppIcons.add,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'Create New Playlist',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showCreatePlaylistDialog(context, item);
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
                              ref
                                  .read(playlistProvider.notifier)
                                  .addTrackToPlaylist(pl.id, item);
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

  static void showCreatePlaylistDialog(BuildContext context, MediaItem item) {
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
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
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
                            await ref
                                .read(playlistProvider.notifier)
                                .createPlaylist(name, isStream: isStream);

                            // 2. Get the new playlist ID from correct list
                            final stateObj = await ref.read(
                              playlistProvider.future,
                            );
                            final targetList = isStream
                                ? stateObj.online
                                : stateObj.local;
                            final newPl = targetList.firstWhere(
                              (p) => p.name == name,
                            );

                            // 3. Add the track to it
                            await ref
                                .read(playlistProvider.notifier)
                                .addTrackToPlaylist(newPl.id, item);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Created "$name" and added song.',
                                  ),
                                ),
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
    final theme = Theme.of(context);
    final isOnline = item.isStreaming;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        UIcons.regular.info,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Metadata Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  ReusableHoverIconButton(
                    icon: UIcons.regular.cross,
                    tooltip: 'Close',
                    iconSize: 16.0,
                    onTap: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metadata Container Card
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _detailRow(theme, 'Title', item.title),
                    _detailRow(theme, 'Artist', item.artist ?? '-'),
                    _detailRow(theme, 'Album', item.album ?? '-'),
                    if (item.date != null && item.date!.isNotEmpty)
                      _detailRow(theme, 'Year', _formatYear(item.date!)),
                    if (item.duration != null && item.duration!.inSeconds > 0)
                      _detailRow(theme, 'Duration', _formatDuration(item.duration!)),
                    _detailRow(
                      theme,
                      'Path/ID',
                      item.id ?? item.path,
                      isCopyable: true,
                      dialogContext: dialogContext,
                    ),
                    _detailRow(
                      theme,
                      'Type',
                      isOnline ? 'Online Stream' : (item.type.toUpperCase()),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ResonanceButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    label: 'Close',
                    style: ResonanceButtonStyle.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatYear(String rawDate) {
    final trimmed = rawDate.trim();
    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!;
    }
    return trimmed;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _detailRow(
    ThemeData theme,
    String label,
    String value, {
    bool isCopyable = false,
    bool isLast = false,
    BuildContext? dialogContext,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (isCopyable)
            ReusableHoverIconButton(
              icon: UIcons.regular.copy,
              tooltip: 'Copy Path/ID',
              iconSize: 14.0,
              padding: 4.0,
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                if (dialogContext != null && dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Copied Path/ID to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
