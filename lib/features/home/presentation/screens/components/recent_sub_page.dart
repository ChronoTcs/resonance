import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/home/presentation/providers/home_navigation_provider.dart';
import 'package:resonance/features/home/presentation/widgets/track_card.dart';
import 'package:resonance/features/home/presentation/widgets/hover_track_card.dart';

class RecentSubPage extends ConsumerWidget {
  const RecentSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentlyPlayedAsync = ref.watch(recentlyPlayedProvider);
    final displayedQuickPicks = ref.watch(homeQuickPicksProvider);

    return SilkyListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Text(
          'Recently Played',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: recentlyPlayedAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        UIcons.regular.time_past,
                        size: 48,
                        color: theme.disabledColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Play a song to see it here.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }
              return SilkyListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (ctx, i) => TrackCard(track: items[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Quick Picks',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Randomly selected from your library',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        if (displayedQuickPicks.isEmpty)
          const _EmptySection(
            icon: Icons.shuffle,
            label: 'Add music to see Quick Picks',
          )
        else
          SizedBox(
            height: 200,
            child: SilkyListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayedQuickPicks.length,
              itemBuilder: (ctx, i) =>
                  HoverTrackCard(track: displayedQuickPicks[i]),
            ),
          ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).disabledColor),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
