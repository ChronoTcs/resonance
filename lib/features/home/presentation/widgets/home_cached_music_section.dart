import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/home/presentation/widgets/hover_track_card.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';

/// Standalone section displaying all cached stream songs on disk.
///
/// Gives offline users instant access to their downloaded/cached stream music.
class HomeCachedMusicSection extends ConsumerWidget {
  const HomeCachedMusicSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(blockedTracksProvider);
    final blockedNotifier = ref.read(blockedTracksProvider.notifier);
    final cachedAsync = ref.watch(cachedStreamMusicProvider);

    return cachedAsync.when(
      data: (rawTracks) {
        final cachedTracks = rawTracks
            .where((t) => !blockedNotifier.isBlocked(t.id, path: t.path))
            .toList();
        if (cachedTracks.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        Icon(UIcons.regular.cloud_download, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Cached Streams',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${cachedTracks.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: SilkyListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: cachedTracks.length,
                    itemBuilder: (ctx, idx) => HoverTrackCard(track: cachedTracks[idx]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
