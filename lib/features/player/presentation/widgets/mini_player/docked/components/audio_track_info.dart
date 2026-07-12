import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/utils/formatters.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

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
    return Row(
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
              Text(
                track.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                      final pos = ref.watch(audioProvider.select((s) => s.position));
                      final dur = ref.watch(audioProvider.select((s) => s.duration));
                      return Text(
                        "${AppFormatters.formatDuration(pos)} / ${AppFormatters.formatDuration(dur)}",
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
