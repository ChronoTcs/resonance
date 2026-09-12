import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Standalone desktop right-click context menu for online playlists.
class OnlinePlaylistContextMenu {
  const OnlinePlaylistContextMenu._();

  /// Displays cursor-anchored desktop context menu for online playlists.
  static Future<void> showAtPosition({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
    required Offset position,
  }) async {
    final theme = Theme.of(context);

    final entries = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'play',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.play, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Play Playlist', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
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
        value: 'save_playlist',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.add_folder, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Save to Playlists', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
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
        MediaActionUtils.playOnlinePlaylist(context, ref, item);
        break;
      case 'play_next':
        MediaActionUtils.addOnlinePlaylistToQueue(context, ref, item, playNext: true);
        break;
      case 'add_queue':
        MediaActionUtils.addOnlinePlaylistToQueue(context, ref, item);
        break;
      case 'save_playlist':
        MediaActionUtils.saveOnlinePlaylist(context, ref, item);
        break;
    }
  }
}
