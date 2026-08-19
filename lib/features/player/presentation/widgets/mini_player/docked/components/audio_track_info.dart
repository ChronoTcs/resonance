import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

import 'package:resonance/core/utils/formatters.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';

class AudioTrackInfo extends ConsumerWidget {
  final MediaItem track;
  final bool isDesktop;

  const AudioTrackInfo({
    super.key,
    required this.track,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNowPlayingOpen = ref.watch(nowPlayingOverlayProvider);
    final tooltipMessage = isNowPlayingOpen
        ? 'Close Now Playing view'
        : 'Open Now Playing view';

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 400),
      child: Row(
      children: [
        // Album Art with Hero Animation
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Hero(
            tag: 'mini_artwork_${track.id ?? track.hashCode}',
            child: MediaArtworkWidget(
              item: track,
              width: 48,
              height: 48,
              borderRadius: 4,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Track Info Text
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row — badge only for streaming tracks
              Row(
                children: [
                  Expanded(
                    child: Text(
                      track.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (track.isStreaming) ...[
                    const SizedBox(width: 6),
                    TrackTypeChip(isVideo: track.type == 'video'),
                  ],
                ],
              ),
              Text(
                track.artist ?? 'Unknown Artist',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final pos = ref.watch(
                        audioProvider.select((s) => s.position),
                      );
                      final dur = ref.watch(
                        audioProvider.select((s) => s.duration),
                      );
                      return Text(
                        "${AppFormatters.formatDuration(pos)} / ${AppFormatters.formatDuration(dur)}",
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

/// Pill badge for streaming tracks: "Song" (blue) or "Video" (purple).
/// Only rendered for streaming tracks — local tracks show nothing.
class TrackTypeChip extends StatelessWidget {
  final bool isVideo;

  const TrackTypeChip({super.key, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final color = isVideo
        ? const Color(0xFFCE93D8) // purple for video
        : const Color(0xFF4FC3F7); // blue for song
    final label = isVideo ? 'Video' : 'Song';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
