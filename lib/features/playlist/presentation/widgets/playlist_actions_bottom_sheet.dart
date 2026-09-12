import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_io_helper.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

/// Modern floating inset card for playlist actions (Play, Rename, Export, Delete).
class PlaylistActionsBottomSheet extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onDeleteSuccess;

  const PlaylistActionsBottomSheet({
    super.key,
    required this.playlist,
    this.onDeleteSuccess,
  });

  /// Displays the modern floating card modal.
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required Playlist playlist,
    VoidCallback? onDeleteSuccess,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => PlaylistActionsBottomSheet(
        playlist: playlist,
        onDeleteSuccess: onDeleteSuccess,
      ),
    );

    if (action == null || !context.mounted) return;

    _handleAction(
      context: context,
      ref: ref,
      playlist: playlist,
      action: action,
      onDeleteSuccess: onDeleteSuccess,
    );
  }

  /// Displays cursor-anchored desktop menu or opens floating modal on mobile.
  static Future<void> showPlaylistMenu({
    required BuildContext context,
    required WidgetRef ref,
    required Playlist playlist,
    Offset? position,
    VoidCallback? onDeleteSuccess,
  }) async {
    final bool useContextMenu = !AppBreakpoints.isCompact(context);

    if (!useContextMenu || position == null) {
      return show(
        context: context,
        ref: ref,
        playlist: playlist,
        onDeleteSuccess: onDeleteSuccess,
      );
    }

    final theme = Theme.of(context);
    final isLiked = playlist.name == 'Liked Songs';

    final entries = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'play',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.play, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Play all', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      if (!isLiked) ...[
        PopupMenuItem<String>(
          value: 'rename',
          height: 38,
          child: Row(
            children: [
              Icon(UIcons.regular.edit, size: 15, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text('Rename', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ],
      PopupMenuItem<String>(
        value: 'export',
        height: 38,
        child: Row(
          children: [
            Icon(UIcons.regular.upload, size: 15, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text('Export JSON', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      if (!isLiked) ...[
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'delete',
          height: 38,
          child: Row(
            children: [
              Icon(UIcons.regular.trash, size: 15, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text('Delete Playlist', style: TextStyle(fontSize: 13, color: theme.colorScheme.error)),
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

    _handleAction(
      context: context,
      ref: ref,
      playlist: playlist,
      action: choice,
      onDeleteSuccess: onDeleteSuccess,
    );
  }

  static void _handleAction({
    required BuildContext context,
    required WidgetRef ref,
    required Playlist playlist,
    required String action,
    VoidCallback? onDeleteSuccess,
  }) {
    switch (action) {
      case 'play':
        if (playlist.tracks.isNotEmpty) {
          ref.read(audioProvider.notifier).playPlaylist(playlist.tracks, initialIndex: 0, playlistId: playlist.id);
        } else {
          ref.read(notificationProvider.notifier).showNotification(
            'Playlist Empty',
            'This playlist has no tracks.',
            isError: true,
            silentOsNotification: true,
          );
        }
        break;
      case 'rename':
        PlaylistIOHelper.renamePlaylistDialog(context, ref, playlist);
        break;
      case 'export':
        PlaylistIOHelper.exportPlaylist(context, ref, playlist.id, playlist.name);
        break;
      case 'delete':
        PlaylistIOHelper.deletePlaylistDialog(
          context,
          ref,
          playlist,
          onDeleteSuccess: onDeleteSuccess,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = playlist.name == 'Liked Songs';
    final firstTrack = playlist.tracks.isNotEmpty ? playlist.tracks.first : null;

    return FloatingSheetShell(
      maxWidth: 440,
      customHeader: _PlaylistHeaderCard(
        playlist: playlist,
        firstTrack: firstTrack,
        isLiked: isLiked,
        subtitle: _buildSubtitle(playlist),
        onClose: () => Navigator.pop(context),
      ),
      children: [
        _PlaylistActionsBento(
          playlist: playlist,
          isLiked: isLiked,
        ),
      ],
    );
  }

  static String _buildSubtitle(Playlist p) {
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

// ── Atomic Sub-Widgets (Zero Pyramid Nesting) ──

class _PlaylistHeaderCard extends StatelessWidget {
  final Playlist playlist;
  final dynamic firstTrack;
  final bool isLiked;
  final String subtitle;
  final VoidCallback onClose;

  const _PlaylistHeaderCard({
    required this.playlist,
    required this.firstTrack,
    required this.isLiked,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: isLiked
                ? Container(
                    color: theme.colorScheme.primaryContainer,
                    alignment: Alignment.center,
                    child: Icon(
                      UIcons.solid.heart,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  )
                : (firstTrack != null
                    ? MediaArtworkWidget(
                        item: firstTrack,
                        width: 52,
                        height: 52,
                        borderRadius: 10,
                        placeholderIcon: UIcons.regular.list_music,
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          UIcons.regular.list_music,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ReusableHoverIconButton(
          icon: UIcons.regular.cross_small,
          tooltip: 'Close',
          iconSize: 13.0,
          padding: 6.0,
          onTap: onClose,
        ),
      ],
    );
  }
}

class _PlaylistActionsBento extends StatelessWidget {
  final Playlist playlist;
  final bool isLiked;

  const _PlaylistActionsBento({
    required this.playlist,
    required this.isLiked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: UIcons.regular.play,
            title: 'Play all tracks',
            onTap: () => Navigator.pop(context, 'play'),
          ),
          if (!isLiked) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withValues(alpha: 0.08)),
            _ActionRow(
              icon: UIcons.regular.edit,
              title: 'Rename playlist',
              onTap: () => Navigator.pop(context, 'rename'),
            ),
          ],
          Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withValues(alpha: 0.08)),
          _ActionRow(
            icon: UIcons.regular.upload,
            title: 'Export JSON',
            onTap: () => Navigator.pop(context, 'export'),
          ),
          if (!isLiked) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withValues(alpha: 0.08)),
            _ActionRow(
              icon: UIcons.regular.trash,
              title: 'Delete playlist',
              iconColor: theme.colorScheme.error,
              titleColor: theme.colorScheme.error,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.iconColor ?? theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.titleColor ?? theme.colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                UIcons.regular.angle_small_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: _isHovered ? 0.9 : 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
