import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

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
      imageUrl: item.thumbnailUrl!,
      width: width,
      height: height,
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

// ── Speed Dial Quick-Launch Grid ─────────────────────────────────────────────

class ExploreSpeedDialSection extends ConsumerWidget {
  const ExploreSpeedDialSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speedDialAsync = ref.watch(speedDialProvider);

    return speedDialAsync.when(
      data: (items) {
        if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(UIcons.regular.waveform, size: 18, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Speed Dial',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 56,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Material(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _playTrackOrStream(ref, item),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              _buildPersonalizedArtwork(
                                item,
                                44,
                                44,
                                theme,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                      item.artist ?? 'Unknown Artist',
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SpeedDialGridSkeleton(),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
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
                  onTap: () => _playTrackOrStream(ref, item),
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

class _PersonalizedOfflineBanner extends StatelessWidget {
  const _PersonalizedOfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      'Personalized mixes unavailable offline',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connect to the internet to discover recommendations tailored to your taste',
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
}

// ── Quick Picks Section ──────────────────────────────────────────────────────

class ExploreQuickPicksSection extends ConsumerWidget {
  const ExploreQuickPicksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(quickPicksProvider);
    return asyncData.when(
      data: (items) {
        if (items.isEmpty) {
          final isOnline = ref.watch(
            networkConnectivityProvider.select((s) => s.isOnline),
          );
          if (!isOnline) {
            return const _PersonalizedOfflineBanner();
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return _TrackCarouselSliverSection(
          title: 'Quick Picks',
          subtitle: 'Personalized recommendations tailored to your taste',
          icon: UIcons.regular.music,
          items: items,
        );
      },
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 100),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// ── Daily Discover Section ───────────────────────────────────────────────────

class ExploreDailyDiscoverSection extends ConsumerWidget {
  const ExploreDailyDiscoverSection({super.key});

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
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 110),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// ── Forgotten Favorites Section ─────────────────────────────────────────────

class ExploreForgottenFavoritesSection extends ConsumerWidget {
  const ExploreForgottenFavoritesSection({super.key});

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
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 140),
      error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

// ── Similar to Artist Rows ───────────────────────────────────────────────────

class ExploreSimilarArtistsSection extends ConsumerWidget {
  const ExploreSimilarArtistsSection({super.key});

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
