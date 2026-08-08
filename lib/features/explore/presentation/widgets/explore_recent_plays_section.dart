import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class ExploreRecentPlaysSection extends ConsumerWidget {
  const ExploreRecentPlaysSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref
        .watch(recentlyPlayedProvider)
        .whenData(
          (items) =>
              items.where((item) => item.id != null && !item.isLocal).toList(),
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Recently Played',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ResonanceButton(
                      onPressed: () {
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
                      icon: UIcons.regular.trash,
                      label: 'Clear',
                      style: ResonanceButtonStyle.danger,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(audioProvider.notifier)
                              .playYouTubeTrack(item);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: item.thumbnailUrl ?? '',
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    AppIcons.music,
                                    color: Colors.grey,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
