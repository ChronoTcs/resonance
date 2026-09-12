import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Modern floating bottom sheet for online playlist actions (Home feed, Explore).
class OnlinePlaylistActionsSheet extends ConsumerWidget {
  final MediaItem item;

  const OnlinePlaylistActionsSheet({super.key, required this.item});

  static Future<void> show({
    required BuildContext context,
    required MediaItem item,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OnlinePlaylistActionsSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingSheetShell(
      maxWidth: 440,
      customHeader: _OnlinePlaylistHeroHeader(
        item: item,
        onClose: () => Navigator.pop(context),
      ),
      children: [
        _OnlinePlaylistActionsBento(
          item: item,
          onClose: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _OnlinePlaylistHeroHeader extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onClose;

  const _OnlinePlaylistHeroHeader({
    required this.item,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
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
          child: MediaArtworkWidget(
            item: item,
            width: 52,
            height: 52,
            borderRadius: 10,
            placeholderIcon: UIcons.regular.list_music,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.artist ?? 'Online Playlist',
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
        const SizedBox(width: 8),
        ReusableHoverIconButton(
          icon: UIcons.regular.cross_small,
          tooltip: 'Close',
          iconSize: 13,
          padding: 6,
          onTap: onClose,
        ),
      ],
    );
  }
}

class _OnlinePlaylistActionsBento extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onClose;

  const _OnlinePlaylistActionsBento({
    required this.item,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          _OnlinePlaylistActionRow(
            icon: UIcons.regular.play,
            title: 'Play Playlist',
            onTap: () {
              onClose();
              MediaActionUtils.playOnlinePlaylist(context, ref, item);
            },
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _OnlinePlaylistActionRow(
            icon: UIcons.regular.step_forward,
            title: 'Play Next',
            onTap: () {
              onClose();
              MediaActionUtils.addOnlinePlaylistToQueue(context, ref, item, playNext: true);
            },
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _OnlinePlaylistActionRow(
            icon: UIcons.regular.list_music,
            title: 'Add to Queue',
            onTap: () {
              onClose();
              MediaActionUtils.addOnlinePlaylistToQueue(context, ref, item);
            },
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _OnlinePlaylistActionRow(
            icon: UIcons.regular.add_folder,
            title: 'Save to Playlists',
            onTap: () {
              onClose();
              MediaActionUtils.saveOnlinePlaylist(context, ref, item);
            },
          ),
        ],
      ),
    );
  }
}

class _OnlinePlaylistActionRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OnlinePlaylistActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_OnlinePlaylistActionRow> createState() => _OnlinePlaylistActionRowState();
}

class _OnlinePlaylistActionRowState extends State<_OnlinePlaylistActionRow> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
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
