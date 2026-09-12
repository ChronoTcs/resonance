import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

/// Shows a compact pop-up dialog for the miniplayer allowing the user to add the
/// current track to any existing playlist, dynamically adapting to active theme.
void showMiniplayerAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  MediaItem track,
) {
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => _AddToPlaylistDialogContent(track: track),
  );
}

class _AddToPlaylistDialogContent extends ConsumerStatefulWidget {
  const _AddToPlaylistDialogContent({required this.track});

  final MediaItem track;

  @override
  ConsumerState<_AddToPlaylistDialogContent> createState() =>
      _AddToPlaylistDialogContentState();
}

class _AddToPlaylistDialogContentState
    extends ConsumerState<_AddToPlaylistDialogContent> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAddToPlaylist(Playlist pl) async {
    final notifier = ref.read(playlistProvider.notifier);
    await notifier.addTrackToPlaylist(pl.id, widget.track);
    if (!mounted) return;
    Navigator.pop(context);
    ref.read(notificationProvider.notifier).showNotification(
      'Playlist Updated',
      'Added "${widget.track.title}" to ${pl.name}',
      target: 'target:playlist:${pl.id}',
      silentOsNotification: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = textColor.withValues(alpha: 0.6);
    final dividerColor = textColor.withValues(alpha: 0.12);
    final playlistAsync = ref.watch(playlistProvider);

    return Dialog(
      backgroundColor: surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogHeader(
              title: widget.track.title,
              textColor: textColor,
              mutedColor: mutedColor,
              onClose: () => Navigator.pop(context),
            ),
            Divider(color: dividerColor, height: 16),
            playlistAsync.when(
              data: (state) => _buildPlaylistList(
                state.playlists,
                textColor,
                mutedColor,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading playlists: $err',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistList(
    List<Playlist> playlists,
    Color textColor,
    Color mutedColor,
  ) {
    if (playlists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No playlists available',
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
        ),
      );
    }

    return Flexible(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SilkyListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final pl = playlists[index];
            return _PlaylistDialogTile(
              playlist: pl,
              textColor: textColor,
              mutedColor: mutedColor,
              onTap: () => _handleAddToPlaylist(pl),
            );
          },
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.textColor,
    required this.mutedColor,
    required this.onClose,
  });

  final String title;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(UIcons.regular.add_folder, color: mutedColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Add to Playlist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  UIcons.regular.cross_small,
                  color: mutedColor,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: mutedColor, fontSize: 11),
        ),
      ],
    );
  }
}

class _PlaylistDialogTile extends StatelessWidget {
  const _PlaylistDialogTile({
    required this.playlist,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  final Playlist playlist;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLiked = playlist.name == 'Liked Songs';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        hoverColor: textColor.withValues(alpha: 0.08),
        splashColor: textColor.withValues(alpha: 0.12),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Icon(
                isLiked ? UIcons.regular.heart : UIcons.regular.music_alt,
                color: isLiked ? Colors.redAccent : mutedColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${playlist.tracks.length} tracks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
