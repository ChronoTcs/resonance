import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

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
    ref.watch(playlistProvider);
    final isLoved = ref.read(playlistProvider.notifier).isLiked(widget.track);

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (event) {
          if (event.kind == PointerDeviceKind.touch) return;
          setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (_isHovered) {
            setState(() => _isHovered = false);
          }
        },
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            if (widget.track.isStreaming) {
              ref.read(audioProvider.notifier).playYouTubeTrack(widget.track);
            } else {
              final library = ref.read(libraryProvider);
              final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
              ref.read(queueOrchestratorProvider).playWithLocalRadioFallback(widget.track, audioTracks);
            }
          },
          onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
            context: context,
            ref: ref,
            item: widget.track,
            position: details.globalPosition,
          ),
          onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: widget.track),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  MediaArtworkWidget(
                    item: widget.track,
                    width: 140,
                    height: 140,
                    borderRadius: 8,
                  ),
                  if (_isHovered)
                    _HoverTrackActionOverlay(
                      track: widget.track,
                      isLoved: isLoved,
                    ),
                ],
              ),

              const SizedBox(height: 6),
              Text(
                widget.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.track.artist ?? 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverTrackActionOverlay extends ConsumerWidget {
  final MediaItem track;
  final bool isLoved;

  const _HoverTrackActionOverlay({
    required this.track,
    required this.isLoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ReusableHoverIconButton(
                icon: UIcons.regular.add,
                iconColor: Colors.white,
                iconSize: 20,
                padding: 6,
                tooltip: 'Add to Playlist',
                onTap: () => MediaActionsBottomSheet.showPlaylistPicker(context, track),
              ),
              const SizedBox(width: 8),
              ReusableHoverIconButton(
                icon: isLoved ? UIcons.solid.heart : UIcons.regular.heart,
                iconColor: isLoved ? Colors.red : Colors.white,
                iconSize: 20,
                padding: 6,
                tooltip: isLoved ? 'Remove from Liked' : 'Like',
                onTap: () => ref
                    .read(playlistProvider.notifier)
                    .toggleLike(track),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
