import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class ExploreRecentPlaysSection extends ConsumerWidget {
  const ExploreRecentPlaysSection({super.key});

  void _playTrackOrStream(WidgetRef ref, dynamic item) {
    if (item.isLocal || (item.path.isNotEmpty && !item.isStreaming && !item.path.startsWith('http'))) {
      ref.read(audioProvider.notifier).playTrack(item);
    } else {
      ref.read(audioProvider.notifier).playYouTubeTrack(item);
    }
  }

  Widget _buildArtwork(dynamic item, double size, ThemeData theme) {
    final localArtPath = (item.thumbnailUrl != null && !item.thumbnailUrl!.startsWith('http'))
        ? item.thumbnailUrl
        : null;

    Widget imageWidget;
    if (localArtPath != null && File(localArtPath).existsSync()) {
      imageWidget = Image.file(
        File(localArtPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(AppIcons.music, color: Colors.grey),
        ),
      );
    } else if (item.thumbnailUrl != null && item.thumbnailUrl!.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: item.thumbnailUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(AppIcons.music, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(UIcons.regular.music, color: Colors.grey),
        ),
      );
    } else {
      imageWidget = Container(
        width: size,
        height: size,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(AppIcons.music, color: Colors.grey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref
        .watch(recentlyPlayedProvider)
        .whenData(
          (items) =>
              items.where((item) => (item.id ?? item.path).isNotEmpty).toList(),
        );

    return recentAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(UIcons.regular.clock, size: 18, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Recently Played',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.trash,
                      tooltip: 'Clear history',
                      iconSize: 15,
                      padding: 6.0,
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dlg) => ResonanceConfirmDialog(
                            title: 'Clear History',
                            content:
                                'Remove all recently played tracks from your history? This cannot be undone.',
                            confirmLabel: 'Clear',
                            isDanger: true,
                            onConfirm: () {
                              ref
                                  .read(recentlyPlayedProvider.notifier)
                                  .clearHistory();
                            },
                          ),
                        );
                      },
                    ),
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
                            _buildArtwork(item, 140, theme),
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
          ),
        );
      },
      loading: () => const SectionCarouselSliverSkeleton(titleWidth: 120),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
