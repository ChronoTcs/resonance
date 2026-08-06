import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/data/models/explore_home.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

class ExploreHomeFeedSection extends ConsumerStatefulWidget {
  const ExploreHomeFeedSection({super.key});

  @override
  ConsumerState<ExploreHomeFeedSection> createState() => _ExploreHomeFeedSectionState();
}

class _ExploreHomeFeedSectionState extends ConsumerState<ExploreHomeFeedSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeFeedAsync = ref.watch(homeFeedProvider);

    return homeFeedAsync.when(
      data: (sections) {
        if (sections.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, sectionIndex) {
              final section = sections[sectionIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sectionIndex == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Feed',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ReusableHoverIconButton(
                            icon: UIcons.regular.refresh,
                            tooltip: 'Reload feed',
                            iconSize: 18,
                            onTap: () async {
                              ref.invalidate(homeFeedProvider);
                              await ref.read(homeFeedProvider.future).catchError((_) => <ExploreHomeSection>[]);
                            },
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: section.items.length,
                      itemBuilder: (context, itemIndex) {
                        final ExploreHomeItem item = section.items[itemIndex];

                        return Container(
                          width: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => _handleItemTap(context, ref, item),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: item.thumbnailUrl,
                                        width: 140,
                                        height: 140,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: Icon(AppIcons.music, color: Colors.grey),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.music_note, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    if (item.isPlaylist)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.playlist_add, size: 18, color: Colors.white),
                                            tooltip: 'Add to Stream Playlists',
                                            onPressed: () => _importPlaylist(context, ref, item),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (item.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            childCount: sections.length,
          ),
        );
      },
      loading: () => const ExploreFeedSkeleton(),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Future<void> _handleItemTap(BuildContext context, WidgetRef ref, ExploreHomeItem item) async {
    if (item.isPlaylist) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final tracks = await ref
            .read(youtubePlaylistRepositoryProvider)
            .fetchFullPlaylistContents(item.id);
        if (context.mounted) Navigator.pop(context);

        if (tracks.isNotEmpty) {
          final mediaItems = tracks
              .map((t) => MediaItem(
                    id: t.id,
                    title: t.title,
                    artist: t.author,
                    thumbnailUrl: t.thumbnailUrl,
                    path: t.id,
                    type: 'audio',
                  ))
              .toList();
          await ref.read(audioProvider.notifier).playYouTubeTrack(mediaItems.first);
          if (mediaItems.length > 1) {
            ref.read(audioProvider.notifier).addTracksToQueue(mediaItems.sublist(1));
          }
        }
      } catch (e) {
        if (context.mounted) Navigator.pop(context);
      }
    } else {
      final mediaItem = MediaItem(
        id: item.id,
        title: item.title,
        artist: item.subtitle,
        thumbnailUrl: item.thumbnailUrl,
        path: item.id,
        type: 'audio',
      );
      ref.read(audioProvider.notifier).playYouTubeTrack(mediaItem);
    }
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref, ExploreHomeItem item) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final tracks = await ref
          .read(youtubePlaylistRepositoryProvider)
          .fetchFullPlaylistContents(item.id);
      if (context.mounted) Navigator.pop(context);

      final newId = await ref.read(playlistProvider.notifier).createPlaylist(
            item.title,
            isStream: true,
          );
      if (newId != null && tracks.isNotEmpty) {
        final mediaItems = tracks
            .map((t) => MediaItem(
                  id: t.id,
                  title: t.title,
                  artist: t.author,
                  thumbnailUrl: t.thumbnailUrl,
                  path: t.id,
                  type: 'audio',
                ))
            .toList();
        await ref.read(playlistProvider.notifier).addTracksToPlaylist(newId, mediaItems);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist added to Stream Playlists!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add playlist: $e')),
        );
      }
    }
  }
}

class ExploreFeedSkeleton extends StatelessWidget {
  const ExploreFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: ShimmerSkeleton(width: 120, height: 24, borderRadius: BorderRadius.circular(4)),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(width: 140, height: 140, borderRadius: BorderRadius.circular(8)),
                      const SizedBox(height: 8),
                      ShimmerSkeleton(width: 110, height: 16, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 6),
                      ShimmerSkeleton(width: 70, height: 12, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
