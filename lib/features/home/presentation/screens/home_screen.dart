import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/library/data/repositories/library_provider.dart';
import 'package:resonance_app/features/player/data/repositories/audio_provider.dart';
import 'package:resonance_app/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentlyPlayedAsync = ref.watch(recentlyPlayedProvider);
    final library = ref.watch(libraryProvider);

    final audioTracks = library.allMedia
        .where((m) => m.type == 'audio')
        .toList();

    // Quick Picks: shuffle the full library for random recommendations
    final quickPicks = List<MediaItem>.from(audioTracks)..shuffle(Random());
    final displayedQuickPicks = quickPicks.take(10).toList();

    // Recommendations: tracks by unique artists (one per artist)
    final seenArtists = <String>{};
    final recommendations = audioTracks
        .where((t) {
          final artist = t.artist ?? 'Unknown';
          if (seenArtists.contains(artist)) return false;
          seenArtists.add(artist);
          return true;
        })
        .take(10)
        .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          // ── Recently Played ──────────────────────────────────────
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
                          Icons.history,
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
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _TrackCard(track: items[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          const SizedBox(height: 32),

          // ── Quick Picks ──────────────────────────────────────────
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
            _EmptySection(
              icon: Icons.shuffle,
              label: 'Add music to see Quick Picks',
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayedQuickPicks.length,
                itemBuilder: (ctx, i) =>
                    _TrackCard(track: displayedQuickPicks[i]),
              ),
            ),
          const SizedBox(height: 32),

          // ── Recommendations ──────────────────────────────────────
          Text(
            'Explore by Artist',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One track per artist in your library',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          if (recommendations.isEmpty)
            _EmptySection(
              icon: Icons.people_outline,
              label: 'Add music to see recommendations',
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                itemBuilder: (ctx, i) => _TrackCard(
                  track: recommendations[i],
                  showArtistLabel: true,
                ),
              ),
            ),
          const SizedBox(height: 32),

          // ── Your Library Row ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Library',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${audioTracks.length} songs',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (audioTracks.isEmpty)
            _EmptySection(
              icon: Icons.library_music_outlined,
              label: 'Your library is empty',
            )
          else
            ...audioTracks.take(5).map((t) => _TrackListTile(track: t)),
          if (audioTracks.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... and ${audioTracks.length - 5} more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Shared Helper Widgets
// ──────────────────────────────────────────────────────────

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

class _TrackCard extends ConsumerWidget {
  const _TrackCard({required this.track, this.showArtistLabel = false});
  final MediaItem track;
  final bool showArtistLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          ref.read(audioProvider.notifier).playPlaylist([track]);
        },
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => MediaActionsBottomSheet(item: track),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Art
              MediaArtworkWidget(
                item: track,
                width: 140,
                height: 140,
                borderRadius: 10,
              ),
              const SizedBox(height: 8),
              Text(
                showArtistLabel
                    ? (track.artist ?? 'Unknown Artist')
                    : track.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                showArtistLabel
                    ? track.title
                    : (track.artist ?? 'Unknown Artist'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackListTile extends ConsumerWidget {
  const _TrackListTile({required this.track});
  final MediaItem track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: MediaArtworkWidget(
        item: track,
        width: 44,
        height: 44,
        borderRadius: 6,
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist ?? 'Unknown Artist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => ref.read(audioProvider.notifier).playTrack(track),
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => MediaActionsBottomSheet(item: track),
        );
      },
    );
  }
}
