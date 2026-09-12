import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

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

  static Future<void> show({
    required BuildContext context,
    required MediaItem item,
    String? playlistId,
    VoidCallback? onDelete,
    yt.Video? video,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => MediaActionsBottomSheet(
        item: item,
        playlistId: playlistId,
        onDelete: onDelete,
        video: video,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = item.isStreaming;
    ref.watch(playlistProvider);
    final isLoved = ref.read(playlistProvider.notifier).isLiked(item);
    final isDownloaded = ref.watch(libraryProvider).isTrackDownloaded(
          item.id,
          title: item.title,
          artist: item.artist,
        );

    return FloatingSheetShell(
      maxWidth: 440,
      customHeader: _TrackHeroRow(
        item: item,
        isOnline: isOnline,
        onClose: () => Navigator.pop(context),
      ),
      children: [
        if (item.type != 'playlist') ...[
          _TrackQuickActionBar(
            item: item,
            isLoved: isLoved,
          ),
          const SizedBox(height: 10),
        ],
        _TrackBentoActions(
          item: item,
          playlistId: playlistId,
          isOnline: isOnline,
          isDownloaded: isDownloaded,
          video: video,
          onDelete: onDelete,
          onShowDetails: () {
            Navigator.pop(context);
            _showDetailsDialog(context);
          },
        ),
      ],
    );
  }

  static void showPlaylistPicker(BuildContext context, MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _PlaylistPickerSheet(item: item),
    );
  }

  static void showCreatePlaylistDialog(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _CreatePlaylistDialog(item: item),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _MediaDetailsDialog(item: item),
    );
  }
}

class _TrackHeroRow extends StatelessWidget {
  final MediaItem item;
  final bool isOnline;
  final VoidCallback onClose;

  const _TrackHeroRow({
    required this.item,
    required this.isOnline,
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
            placeholderIcon: isOnline ? UIcons.regular.world : UIcons.regular.music,
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
                item.artist ?? 'Unknown Artist',
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

class _TrackQuickActionBar extends ConsumerWidget {
  final MediaItem item;
  final bool isLoved;

  const _TrackQuickActionBar({
    required this.item,
    required this.isLoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: UIcons.regular.play,
            label: 'Play',
            onTap: () {
              Navigator.pop(context);
              if (item.isStreaming) {
                ref.read(audioProvider.notifier).playYouTubeTrack(item);
              } else {
                ref.read(audioProvider.notifier).playTrack(item);
              }
            },
          ),
          _QuickActionButton(
            icon: UIcons.regular.step_forward,
            label: 'Play Next',
            onTap: () {
              Navigator.pop(context);
              ref.read(audioProvider.notifier).playNext(item);
            },
          ),
          _QuickActionButton(
            icon: UIcons.regular.list_music,
            label: 'Queue',
            onTap: () {
              Navigator.pop(context);
              ref.read(audioProvider.notifier).addToQueue(item);
            },
          ),
          _QuickActionButton(
            icon: isLoved ? UIcons.solid.heart : UIcons.regular.heart,
            iconColor: isLoved ? Colors.redAccent : null,
            label: isLoved ? 'Liked' : 'Like',
            onTap: () {
              ref.read(playlistProvider.notifier).toggleLike(item);
            },
          ),
        ],
      ),
    );
  }
}

class _TrackBentoActions extends ConsumerWidget {
  final MediaItem item;
  final String? playlistId;
  final bool isOnline;
  final bool isDownloaded;
  final yt.Video? video;
  final VoidCallback? onDelete;
  final VoidCallback onShowDetails;

  const _TrackBentoActions({
    required this.item,
    this.playlistId,
    required this.isOnline,
    required this.isDownloaded,
    this.video,
    this.onDelete,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Group 1: Playlist & Download
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            children: [
              if (item.type != 'playlist') ...[
                if (playlistId == null)
                  _ActionCardRow(
                    icon: UIcons.regular.add_folder,
                    title: 'Add to playlist',
                    onTap: () {
                      Navigator.pop(context);
                      MediaActionsBottomSheet.showPlaylistPicker(context, item);
                    },
                  )
                else
                  _ActionCardRow(
                    icon: UIcons.regular.cross_small,
                    iconColor: Colors.redAccent,
                    title: 'Remove from this playlist',
                    titleColor: Colors.redAccent,
                    onTap: () {
                      ref
                          .read(playlistProvider.notifier)
                          .removeTrackFromPlaylist(playlistId!, item.id ?? item.path);
                      Navigator.pop(context);
                    },
                  ),
              ],
              if (item.type != 'playlist' && isOnline && !isDownloaded && item.id != null) ...[
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                _ActionCardRow(
                  icon: UIcons.regular.download,
                  title: 'Download to library',
                  onTap: () {
                    ref
                        .read(downloadProvider.notifier)
                        .addToQueue(
                          [item.id!],
                          type: DownloadType.audio,
                          source: DownloadSource.ytmusic,
                          video: video,
                        );
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
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Group 2: Song details
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: _ActionCardRow(
            icon: UIcons.regular.info,
            title: 'Song details',
            onTap: onShowDetails,
          ),
        ),
        const SizedBox(height: 8),

        // Group 3: Block/Unblock
        Builder(
          builder: (context) {
            final isBlocked = ref.watch(blockedTracksProvider.select((list) =>
                ref.read(blockedTracksProvider.notifier).isBlocked(item.id, path: item.path)));
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: _ActionCardRow(
                icon: isBlocked ? UIcons.regular.check_circle : UIcons.regular.ban,
                iconColor: isBlocked ? theme.colorScheme.primary : theme.colorScheme.error,
                title: isBlocked ? 'Unblock track' : 'Block from feed & queue',
                titleColor: isBlocked ? theme.colorScheme.primary : theme.colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  MediaActionUtils.toggleBlockTrack(context, ref, item);
                },
              ),
            );
          },
        ),

        // Group 3: Delete (if applicable)
        if (onDelete != null) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: _ActionCardRow(
              icon: UIcons.regular.trash,
              iconColor: Colors.redAccent,
              title: 'Delete from device',
              titleColor: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaylistPickerSheet extends ConsumerWidget {
  final MediaItem item;

  const _PlaylistPickerSheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playlistsAsync = ref.watch(playlistProvider);

    return playlistsAsync.when(
      data: (state) {
        final targetList = state.playlists;

        return FloatingSheetShell(
          maxWidth: 440,
          maxHeight: 520,
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
          isScrollable: false,
          customHeader: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Playlist',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ReusableHoverIconButton(
                  icon: UIcons.regular.cross_small,
                  tooltip: 'Close',
                  iconSize: 13.0,
                  padding: 6.0,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          children: [
            Material(
              color: Colors.transparent,
              child: ListTile(
                mouseCursor: SystemMouseCursors.click,
                leading: Icon(
                  UIcons.regular.add,
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
                  MediaActionsBottomSheet.showCreatePlaylistDialog(context, item);
                },
              ),
            ),
            const Divider(height: 1),
            if (targetList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No playlists found. Create one above.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targetList.length,
                  itemBuilder: (ctx, i) {
                    final pl = targetList[i];
                    final notifier = ref.read(playlistProvider.notifier);
                    final bool isAlreadyIn = notifier.isTrackInPlaylist(pl.id, item);

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        mouseCursor: SystemMouseCursors.click,
                        leading: Icon(
                          pl.name == 'Liked Songs' ? UIcons.regular.heart : UIcons.regular.list_music,
                          color: isAlreadyIn ? theme.colorScheme.primary : null,
                        ),
                        title: Text(pl.name),
                        subtitle: Text('${pl.tracks.length} tracks'),
                        trailing: isAlreadyIn
                            ? Icon(UIcons.regular.check, color: theme.colorScheme.primary, size: 18)
                            : null,
                        onTap: () async {
                          final added = await notifier.addTrackToPlaylist(pl.id, item);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ref.read(notificationProvider.notifier).showNotification(
                              'Playlist Updated',
                              added ? 'Added to ${pl.name}' : 'Already in ${pl.name}',
                              target: 'target:playlist:${pl.id}',
                              silentOsNotification: true,
                            );
                          }
                        },
                      ),
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
  }
}

class _CreatePlaylistDialog extends ConsumerStatefulWidget {
  final MediaItem item;

  const _CreatePlaylistDialog({required this.item});

  @override
  ConsumerState<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<_CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      final notifier = ref.read(playlistProvider.notifier);
      final newId = await notifier.createPlaylist(name);

      if (newId != null) {
        await notifier.addTrackToPlaylist(newId, widget.item);
      }

      if (mounted) {
        Navigator.pop(context);
        ref.read(notificationProvider.notifier).showNotification(
          'Playlist Created',
          'Created "$name" and added song.',
          target: newId != null ? 'target:playlist:$newId' : 'target:playlists',
          silentOsNotification: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              'New Playlist',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
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
                  onPressed: () => Navigator.pop(context),
                  label: 'Cancel',
                  style: ResonanceButtonStyle.secondary,
                ),
                const SizedBox(width: 12),
                ResonanceButton(
                  onPressed: _handleCreate,
                  label: 'Create',
                  style: ResonanceButtonStyle.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaDetailsDialog extends StatelessWidget {
  final MediaItem item;

  const _MediaDetailsDialog({required this.item});

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
            Consumer(
              builder: (ctx, ref, _) => ReusableHoverIconButton(
                icon: UIcons.regular.copy,
                tooltip: 'Copy Path/ID',
                iconSize: 14.0,
                padding: 4.0,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ref.read(notificationProvider.notifier).showNotification(
                    'Copied to Clipboard',
                    'Copied $label to clipboard',
                    silentOsNotification: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = item.isStreaming;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
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
                      icon: UIcons.regular.cross_small,
                      tooltip: 'Close',
                      iconSize: 13.0,
                      padding: 6.0,
                      onTap: () => Navigator.pop(context),
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
                      _detailRow(
                        theme,
                        'Duration',
                        _formatDuration(item.duration ?? Duration.zero),
                      ),
                      _detailRow(
                        theme,
                        'Path/ID',
                        item.path,
                        isCopyable: true,
                        dialogContext: context,
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ResonanceButton(
                          onPressed: () => Navigator.pop(context),
                          label: 'Close',
                          style: ResonanceButtonStyle.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
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
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? theme.primaryColor.withValues(alpha: 0.18)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isHovered
                          ? theme.primaryColor.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 19,
                      color: _isHovered
                          ? (widget.iconColor ?? theme.primaryColor)
                          : (widget.iconColor ?? theme.colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: _isHovered ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCardRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _ActionCardRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  State<_ActionCardRow> createState() => _ActionCardRowState();
}

class _ActionCardRowState extends State<_ActionCardRow> {
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

