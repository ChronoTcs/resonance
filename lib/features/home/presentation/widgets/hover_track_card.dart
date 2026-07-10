import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/widgets/media_actions_bottom_sheet.dart';

class HoverTrackCard extends ConsumerStatefulWidget {
  const HoverTrackCard({super.key, required this.track});
  final MediaItem track;

  @override
  ConsumerState<HoverTrackCard> createState() => _HoverTrackCardState();
}

class _HoverTrackCardState extends ConsumerState<HoverTrackCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistState = ref.watch(playlistProvider).value;
    
    bool isLoved = false;
    String? likedPlaylistId;
    if (playlistState != null) {
      final likedPl = playlistState.local.cast<Playlist?>().firstWhere(
            (p) => p?.name == 'Liked Songs',
            orElse: () => null,
          );
      if (likedPl != null) {
        likedPlaylistId = likedPl.id;
        final trackId = widget.track.id ?? widget.track.path;
        isLoved = likedPl.tracks.any((t) => (t.id ?? t.path) == trackId);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () {
            final library = ref.read(libraryProvider);
            final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
            ref.read(queueOrchestratorProvider).playWithLocalRadioFallback(widget.track, audioTracks);
          },
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => MediaActionsBottomSheet(item: widget.track),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    MediaArtworkWidget(
                      item: widget.track,
                      width: 140,
                      height: 140,
                      borderRadius: 10,
                    ),
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(AppIcons.add, color: Colors.white),
                                  iconSize: 22,
                                  onPressed: () {
                                    ref.read(audioProvider.notifier).addTrackToQueue(widget.track);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added "${widget.track.title}" to play queue', style: const TextStyle(color: Colors.white)),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: theme.primaryColor,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    isLoved ? UIcons.solid.heart : UIcons.regular.heart,
                                    color: isLoved ? Colors.red : Colors.white,
                                  ),
                                  iconSize: 22,
                                  onPressed: () async {
                                    final notifier = ref.read(playlistProvider.notifier);
                                    if (likedPlaylistId == null) {
                                      await notifier.createPlaylist('Liked Songs');
                                      await Future.delayed(const Duration(milliseconds: 200));
                                      final updatedState = ref.read(playlistProvider).value;
                                      final newLikedPl = updatedState?.local.firstWhere((p) => p.name == 'Liked Songs');
                                      if (newLikedPl != null) {
                                        likedPlaylistId = newLikedPl.id;
                                      }
                                    }
                                    if (likedPlaylistId != null) {
                                      if (isLoved) {
                                        await notifier.removeTrackFromPlaylist(likedPlaylistId!, widget.track.id ?? widget.track.path);
                                      } else {
                                        await notifier.addTrackToPlaylist(likedPlaylistId!, widget.track);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.track.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.track.artist ?? 'Unknown Artist',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
