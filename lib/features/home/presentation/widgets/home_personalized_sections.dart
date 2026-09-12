import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

void _playTrackOrStream(WidgetRef ref, MediaItem item) {
  if (item.isLocal || (item.path.isNotEmpty && !item.isStreaming && !item.path.startsWith('http'))) {
    ref.read(audioProvider.notifier).playTrack(item);
  } else {
    ref.read(audioProvider.notifier).playYouTubeTrack(item);
  }
}

Widget _buildPersonalizedArtwork(
  MediaItem item,
  double width,
  double height,
  ThemeData theme, {
  BorderRadius? borderRadius,
}) {
  final radius = borderRadius ?? BorderRadius.circular(8);
  final localArtPath = (item.thumbnailUrl != null && !item.thumbnailUrl!.startsWith('http'))
      ? item.thumbnailUrl
      : null;

  Widget imageWidget;
  if (localArtPath != null && File(localArtPath).existsSync()) {
    imageWidget = Image.file(
      File(localArtPath),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(AppIcons.music, size: width > 60 ? 28 : 20, color: Colors.grey),
      ),
    );
  } else if (item.thumbnailUrl != null && item.thumbnailUrl!.startsWith('http')) {
    imageWidget = CachedNetworkImage(
      imageUrl: ThumbnailUtils.toCardResolution(item.thumbnailUrl!),
      width: width,
      height: height,
      memCacheWidth: 400,
      memCacheHeight: 400,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(AppIcons.music, size: width > 60 ? 28 : 20, color: Colors.grey),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(AppIcons.music, size: width > 60 ? 28 : 20, color: Colors.grey),
      ),
    );
  } else {
    imageWidget = Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(AppIcons.music, size: width > 60 ? 28 : 20, color: Colors.grey),
    );
  }

  return ClipRRect(
    borderRadius: radius,
    child: imageWidget,
  );
}

// ── Generic Track Carousel (Box Widget) ──────────────────────────────────────

class _TrackCarouselBoxSection extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<MediaItem> items;

  const _TrackCarouselBoxSection({
    required this.title,
    this.subtitle,
    this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: theme.primaryColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: SilkyListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  onTap: () => _playTrackOrStream(ref, item),
                  onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
                    context: context,
                    ref: ref,
                    item: item,
                    position: details.globalPosition,
                  ),
                  onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: item),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPersonalizedArtwork(
                        item,
                        140,
                        140,
                        theme,
                        borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(height: 2),
                      Text(
                        item.artist ?? '',
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
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Generic Track Carousel (Sliver Adapter Wrapper) ──────────────────────────

class _TrackCarouselSliverSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<MediaItem> items;

  const _TrackCarouselSliverSection({
    required this.title,
    this.subtitle,
    this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: _TrackCarouselBoxSection(
        title: title,
        subtitle: subtitle,
        icon: icon,
        items: items,
      ),
    );
  }
}

// ── Daily Discover Section ───────────────────────────────────────────────────

class HomeDailyDiscoverSection extends ConsumerWidget {
  const HomeDailyDiscoverSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dailyDiscoverProvider);
    return asyncData.when(
      data: (items) => _TrackCarouselSliverSection(
        title: 'Daily Discover',
        subtitle: 'Fresh mix seeded by your top listening trends',
        icon: UIcons.regular.globe,
        items: items,
      ),
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 110, subtitleWidth: 200),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// ── Forgotten Favorites Section ─────────────────────────────────────────────

class HomeForgottenFavoritesSection extends ConsumerWidget {
  const HomeForgottenFavoritesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(forgottenFavoritesProvider);
    return asyncData.when(
      data: (items) => _TrackCarouselSliverSection(
        title: 'Forgotten Favorites',
        subtitle: 'Rediscover tracks you used to love',
        icon: UIcons.regular.heart,
        items: items,
      ),
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 140, subtitleWidth: 175),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// ── Similar to Artist Rows ───────────────────────────────────────────────────

class HomeSimilarArtistsSection extends ConsumerWidget {
  const HomeSimilarArtistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(similarArtistsProvider);
    return asyncData.when(
      data: (artistRows) {
        if (artistRows.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final row = artistRows[index];
              return _TrackCarouselBoxSection(
                title: 'Similar to ${row.artist}',
                subtitle: 'Based on your history with ${row.artist}',
                icon: UIcons.regular.user,
                items: row.tracks,
              );
            },
            childCount: artistRows.length,
          ),
        );
      },
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 130),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// Backward-compatible aliases
typedef ExploreDailyDiscoverSection = HomeDailyDiscoverSection;
typedef ExploreForgottenFavoritesSection = HomeForgottenFavoritesSection;
typedef ExploreSimilarArtistsSection = HomeSimilarArtistsSection;
