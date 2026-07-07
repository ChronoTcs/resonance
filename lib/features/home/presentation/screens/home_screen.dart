import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import 'package:resonance_app/core/utils/app_icons.dart';
import 'package:resonance_app/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/library/application/library_provider.dart';
import 'package:resonance_app/features/player/application/services/queue_orchestrator.dart';
import 'package:resonance_app/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';
import 'package:resonance_app/features/playlist/application/playlist_provider.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import 'package:resonance_app/features/player/application/providers/audio_provider.dart';
import 'package:resonance_app/core/widgets/top_navigation_header.dart';

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
      body: Column(
        children: [
          const TopNavigationHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              icon: AppIcons.shuffle,
              label: 'Add music to see Quick Picks',
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayedQuickPicks.length,
                itemBuilder: (ctx, i) =>
                    _HoverTrackCard(track: displayedQuickPicks[i]),
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
              icon: UIcons.regular.users,
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
              icon: AppIcons.music,
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
          final library = ref.read(libraryProvider);
          final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
          ref.read(queueOrchestratorProvider).playWithLocalRadioFallback(track, audioTracks);
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
      onTap: () {
        final library = ref.read(libraryProvider);
        final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
        ref.read(queueOrchestratorProvider).playSequentialContext(track, audioTracks);
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => MediaActionsBottomSheet(item: track),
        );
      },
    );
  }
}

class _HoverTrackCard extends ConsumerStatefulWidget {
  const _HoverTrackCard({required this.track});
  final MediaItem track;

  @override
  ConsumerState<_HoverTrackCard> createState() => _HoverTrackCardState();
}

class _HoverTrackCardState extends ConsumerState<_HoverTrackCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistState = ref.watch(playlistProvider).value;
    
    bool isLoved = false;
    String? likedPlaylistId;
    if (playlistState != null) {
      final likedPl = playlistState.local.cast<Playlist?>().firstWhere(
            (p) => p?.name == 'Liked Songs',
            orElse: () => null,
          );
      if (likedPl != null) {
        likedPlaylistId = likedPl.id;
        final trackId = widget.track.id ?? widget.track.path;
        isLoved = likedPl.tracks.any((t) => (t.id ?? t.path) == trackId);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () {
            final library = ref.read(libraryProvider);
            final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
            ref.read(queueOrchestratorProvider).playWithLocalRadioFallback(widget.track, audioTracks);
          },
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => MediaActionsBottomSheet(item: widget.track),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    MediaArtworkWidget(
                      item: widget.track,
                      width: 140,
                      height: 140,
                      borderRadius: 10,
                    ),
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(AppIcons.add, color: Colors.white),
                                  iconSize: 22,
                                  onPressed: () {
                                    ref.read(audioProvider.notifier).addTrackToQueue(widget.track);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added "${widget.track.title}" to play queue', style: const TextStyle(color: Colors.white)),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: theme.primaryColor,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    isLoved ? UIcons.solid.heart : UIcons.regular.heart,
                                    color: isLoved ? Colors.red : Colors.white,
                                  ),
                                  iconSize: 22,
                                  onPressed: () async {
                                    final notifier = ref.read(playlistProvider.notifier);
                                    if (likedPlaylistId == null) {
                                      await notifier.createPlaylist('Liked Songs');
                                      await Future.delayed(const Duration(milliseconds: 200));
                                      final updatedState = ref.read(playlistProvider).value;
                                      final newLikedPl = updatedState?.local.firstWhere((p) => p.name == 'Liked Songs');
                                      if (newLikedPl != null) {
                                        likedPlaylistId = newLikedPl.id;
                                      }
                                    }
                                    if (likedPlaylistId != null) {
                                      if (isLoved) {
                                        await notifier.removeTrackFromPlaylist(likedPlaylistId!, widget.track.id ?? widget.track.path);
                                      } else {
                                        await notifier.addTrackToPlaylist(likedPlaylistId!, widget.track);
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.track.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.track.artist ?? 'Unknown Artist',
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
      ),
    );
  }
}
