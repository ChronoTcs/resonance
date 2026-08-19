import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

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
    builder: (ctx) {
      final scrollController = ScrollController();
      final theme = Theme.of(ctx);
      final surfaceColor = theme.colorScheme.surface;
      final textColor = theme.colorScheme.onSurface;
      final mutedColor = textColor.withValues(alpha: 0.6);
      final dividerColor = textColor.withValues(alpha: 0.12);

      return Dialog(
        backgroundColor: surfaceColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          child: Consumer(
            builder: (context, ref, child) {
              final playlistAsync = ref.watch(playlistProvider);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Header
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
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(UIcons.regular.cross_small, color: mutedColor, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
                  Divider(color: dividerColor, height: 16),

                  // Playlist Scrollable List
                  playlistAsync.when(
                    data: (state) {
                      final playlists = state.local;
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
                          controller: scrollController,
                          thumbVisibility: true,
                          child: SilkyListView.builder(
                            controller: scrollController,
                            shrinkWrap: true,
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final pl = playlists[index];
                              final isLiked = pl.name == 'Liked Songs';

                              return Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                child: InkWell(
                                  hoverColor: textColor.withValues(alpha: 0.08),
                                  splashColor: textColor.withValues(alpha: 0.12),
                                  onTap: () async {
                                    final notifier = ref.read(playlistProvider.notifier);
                                    await notifier.addTrackToPlaylist(pl.id, track);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added "${track.title}" to ${pl.name}'),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
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
                                                pl.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${pl.tracks.length} tracks',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: mutedColor,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading playlists: $err', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
