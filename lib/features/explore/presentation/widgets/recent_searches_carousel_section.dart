import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/presentation/widgets/recent_searches_card.dart';
import 'package:resonance/features/explore/presentation/providers/recent_searches_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';

/// Horizontal carousel displaying recent searches / tracks played from search.
///
/// Matches Picture 1 ("Recent searches").
class RecentSearchesCarouselSection extends ConsumerWidget {
  final String title;
  final ValueChanged<MediaItem>? onTrackSelected;

  const RecentSearchesCarouselSection({
    super.key,
    this.title = 'Recent searches',
    this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref.watch(recentSearchesProvider);
    final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));
    final cachedAsync = ref.watch(cachedStreamMusicProvider);
    final cachedIds = cachedAsync.asData?.value.map((t) => t.id ?? t.path).toSet() ?? {};

    return recentAsync.when(
      data: (items) {
        final validItems = items
            .where((item) => (item.id ?? item.path).isNotEmpty)
            .where((item) {
              if (isOnline) return true;
              final isLocal = !item.isStreaming ||
                  (item.path.isNotEmpty &&
                      !item.path.startsWith('http') &&
                      (item.path.contains('/') || item.path.contains('\\')));
              return isLocal || cachedIds.contains(item.id ?? item.path);
            })
            .take(12)
            .toList();

        if (validItems.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(UIcons.regular.search, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.trash,
                      tooltip: 'Clear search history',
                      iconSize: 14,
                      padding: 6.0,
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dlg) => ResonanceConfirmDialog(
                            title: 'Clear Search History',
                            content: 'Remove all recent search tracks? This cannot be undone.',
                            confirmLabel: 'Clear',
                            isDanger: true,
                            onConfirm: () {
                              ref.read(recentSearchesProvider.notifier).clearSearchHistory();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Horizontal Carousel
              SizedBox(
                height: 145,
                child: SilkyListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: validItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = validItems[index];
                    return RecentSearchesCard(
                      item: item,
                      size: 105,
                      onTap: onTrackSelected != null
                          ? () => onTrackSelected!(item)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const RecentSearchesCarouselSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
