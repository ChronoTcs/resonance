import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';

import 'package:resonance/features/player/utils/media_action_utils.dart';

class TrackCard extends ConsumerWidget {
  const TrackCard({super.key, required this.track});
  final MediaItem track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          if (track.isStreaming) {
            ref.read(audioProvider.notifier).playYouTubeTrack(track);
          } else {
            final library = ref.read(libraryProvider);
            final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
            ref.read(queueOrchestratorProvider).playWithLocalRadioFallback(track, audioTracks);
          }
        },
        onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
          context: context,
          ref: ref,
          item: track,
          position: details.globalPosition,
        ),
        onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: track),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaArtworkWidget(
                item: track,
                width: 140,
                height: 140,
                borderRadius: 10,
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                track.artist ?? 'Unknown Artist',
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
    );
  }
}
