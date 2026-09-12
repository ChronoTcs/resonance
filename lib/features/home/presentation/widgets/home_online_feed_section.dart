import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/explore/data/models/explore_home.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Online recommendation feeds from YouTube Music on Home screen (Mixed for you, Listen again, Trending, Charts)
class HomeOnlineFeedSection extends ConsumerStatefulWidget {
  const HomeOnlineFeedSection({super.key});

  @override
  ConsumerState<HomeOnlineFeedSection> createState() =>
      _HomeOnlineFeedSectionState();
}

class _HomeOnlineFeedSectionState extends ConsumerState<HomeOnlineFeedSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeFeedAsync = ref.watch(homeFeedProvider);

    return homeFeedAsync.when(
      data: (sections) {
        if (sections.isEmpty) {
          final isOnline = ref.watch(
            networkConnectivityProvider.select((s) => s.isOnline),
          );
          if (!isOnline) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        UIcons.regular.wifi_slash,
                        size: 20,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore feed unavailable offline',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Connect to the internet to browse trending community playlists and global music feeds',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, sectionIndex) {
            final section = sections[sectionIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Icon(UIcons.regular.sparkles, size: 18, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        section.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: SilkyListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: section.items.length,
                    itemBuilder: (context, itemIndex) {
                      final ExploreHomeItem item = section.items[itemIndex];

                      return _OnlineFeedCard(
                        item: item,
                        onTap: () => _handleItemTap(context, ref, item),
                        onLongPress: () {
                          final mediaItem = MediaItem(
                            id: item.id,
                            path: item.id,
                            title: item.title,
                            artist: item.subtitle,
                            thumbnailUrl: item.thumbnailUrl,
                            type: item.isPlaylist ? 'playlist' : 'audio',
                          );
                          MediaActionUtils.showMediaActions(
                            context: context,
                            ref: ref,
                            item: mediaItem,
                          );
                        },
                        onImportPlaylist: () =>
                            _importPlaylist(context, ref, item),
                      );
                    },
                  ),
                ),
              ],
            );
          }, childCount: sections.length),
        );
      },
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 120),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Future<void> _handleItemTap(
    BuildContext context,
    WidgetRef ref,
    ExploreHomeItem item,
  ) async {
    final mediaItem = MediaItem(
      id: item.id,
      path: item.id,
      title: item.title,
      artist: item.subtitle,
      thumbnailUrl: item.thumbnailUrl,
      type: item.isPlaylist ? 'playlist' : 'audio',
    );

    if (item.isPlaylist) {
      await MediaActionUtils.playOnlinePlaylist(context, ref, mediaItem);
    } else {
      ref.read(audioProvider.notifier).playYouTubeTrack(mediaItem);
    }
  }

  Future<void> _importPlaylist(
    BuildContext context,
    WidgetRef ref,
    ExploreHomeItem item,
  ) async {
    final mediaItem = MediaItem(
      id: item.id,
      path: item.id,
      title: item.title,
      artist: item.subtitle,
      thumbnailUrl: item.thumbnailUrl,
      type: 'playlist',
    );
    await MediaActionUtils.saveOnlinePlaylist(context, ref, mediaItem);
  }
}

class _OnlineFeedCard extends ConsumerWidget {
  const _OnlineFeedCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onImportPlaylist,
  });

  final ExploreHomeItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onImportPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaItem = MediaItem(
      id: item.id,
      path: item.id,
      title: item.title,
      artist: item.subtitle,
      thumbnailUrl: item.thumbnailUrl,
      type: item.isPlaylist ? 'playlist' : 'audio',
    );

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
          context: context,
          ref: ref,
          item: mediaItem,
          position: details.globalPosition,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ThumbnailUtils.toCardResolution(item.thumbnailUrl),
                    width: 140,
                    height: 140,
                    memCacheWidth: 400,
                    memCacheHeight: 400,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(AppIcons.music, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(UIcons.regular.music, color: Colors.grey),
                    ),
                  ),
                ),
                if (item.isPlaylist)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ReusableHoverIconButton(
                      icon: UIcons.regular.add_folder,
                      tooltip: 'Save to Playlists',
                      iconSize: 16,
                      padding: 6.0,
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      onTap: onImportPlaylist,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
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
  }
}

// Backward-compatible alias
typedef ExploreHomeFeedSection = HomeOnlineFeedSection;
