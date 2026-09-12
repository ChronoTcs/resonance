import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/dialogs/resonance_confirm_dialog.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Standalone desktop right-click context menu for music tracks.
class TrackContextMenu {
  const TrackContextMenu._();

  /// Displays cursor-anchored desktop context menu.
  static Future<void> showAtPosition({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
    required Offset position,
    String? playlistId,
    VoidCallback? onRemoveFromQueue,
  }) async {
    final theme = Theme.of(context);
    final isLoved = ref.read(playlistProvider.notifier).isLiked(item);
    final isOnline = item.isStreaming;
    final isDownloaded = ref.read(libraryProvider).isTrackDownloaded(
          item.id,
          title: item.title,
          artist: item.artist,
        );

    final isBlocked = ref.read(blockedTracksProvider.notifier).isBlocked(item.id, path: item.path);

    final entries = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'play',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.play, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Play Now', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'play_next',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.step_forward, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Play Next', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'add_queue',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.list_music, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Add to Queue', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem<String>(
        value: 'add_playlist',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.add_folder, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Add to Playlist', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'toggle_like',
        height: 38,
        child: Row(
          children: [
            Icon(
              isLoved ? UIcons.solid.heart : UIcons.regular.heart,
              size: 15,
              color: isLoved ? Colors.red : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              isLoved ? 'Remove from Liked' : 'Like Track',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'toggle_block',
        height: 38,
        child: Row(
          children: [
            Icon(
              isBlocked ? UIcons.regular.check_circle : UIcons.regular.ban,
              size: 15,
              color: isBlocked ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Text(
              isBlocked ? 'Unblock Track' : 'Block Track',
              style: TextStyle(
                fontSize: 13,
                color: isBlocked ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
      if (isOnline && !isDownloaded && item.id != null) ...[
        PopupMenuItem<String>(
          value: 'download',
          height: 38,
          child: Row(
            children: [
              Icon(UIcons.regular.download, size: 15, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text('Download to Library', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ],
      if (playlistId != null) ...[
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'remove_from_playlist',
          height: 38,
          child: Row(
            children: [
              Icon(UIcons.regular.cross_small, size: 15, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Remove from Playlist',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      if (onRemoveFromQueue != null) ...[
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'remove_from_queue',
          height: 38,
          child: Row(
            children: [
              Icon(UIcons.regular.cross_small, size: 15, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Remove from Queue',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      if (item.isLocal || item.id == null) ...[
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'delete',
          height: 38,
          child: Row(
            children: [
              Icon(UIcons.regular.trash, size: 15, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Delete from Device',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ];

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlayRect = overlay != null
        ? RelativeRect.fromRect(
            Rect.fromPoints(position, position),
            Offset.zero & overlay.size,
          )
        : RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1);

    final choice = await showMenu<String>(
      context: context,
      position: overlayRect,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      items: entries,
    );

    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'play':
        if (item.isStreaming) {
          ref.read(audioProvider.notifier).playYouTubeTrack(item);
        } else {
          ref.read(audioProvider.notifier).playTrack(item);
        }
        break;
      case 'play_next':
        ref.read(audioProvider.notifier).playNext(item);
        break;
      case 'add_queue':
        ref.read(audioProvider.notifier).addToQueue(item);
        break;
      case 'add_playlist':
        MediaActionsBottomSheet.showPlaylistPicker(context, item);
        break;
      case 'toggle_like':
        ref.read(playlistProvider.notifier).toggleLike(item);
        break;
      case 'download':
        if (item.id != null) {
          ref.read(downloadProvider.notifier).addToQueue(
            [item.id!],
            type: DownloadType.audio,
            source: DownloadSource.ytmusic,
          );
          ref.read(notificationProvider.notifier).showNotification(
            'Download Started',
            'Downloading "${item.title}" to library...',
            target: 'target:download',
          );
        }
        break;
      case 'remove_from_playlist':
        if (playlistId != null) {
          ref.read(playlistProvider.notifier).removeTrackFromPlaylist(
            playlistId,
            item.id ?? item.path,
          );
        }
        break;
      case 'remove_from_queue':
        onRemoveFromQueue?.call();
        break;
      case 'delete':
        _confirmDelete(context, ref, item);
        break;
      case 'toggle_block':
        MediaActionUtils.toggleBlockTrack(context, ref, item);
        break;
    }
  }

  static void _confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => Consumer(
        builder: (ctx, dialogRef, _) => ResonanceConfirmDialog(
          title: 'Delete Track',
          content: 'Permanently delete "${item.title}" from your device? This cannot be undone.',
          confirmLabel: 'Delete',
          isDanger: true,
          onConfirm: () {
            dialogRef.read(libraryProvider.notifier).deleteTrack(item);
            final audioState = dialogRef.read(audioProvider);
            if (audioState.currentTrack?.path == item.path) {
              dialogRef.read(audioProvider.notifier).next();
            }
          },
        ),
      ),
    );
  }
}
