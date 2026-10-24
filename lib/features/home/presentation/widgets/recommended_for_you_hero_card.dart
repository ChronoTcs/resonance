import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/card_hover_play_button.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/media/media_artwork_widget.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';
import 'package:resonance/core/widgets/common/shimmer_skeleton.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

/// "Recommended for You" Hero Card on Desktop Wide layouts.
///
/// Dual-column layout:
/// - Left column: Prominent square cover artwork with quick-play hover overlay.
/// - Right column: 5-track interactive recommendation list with live equalizer,
///   like heart, title, artist, duration, and tap-to-play.
class RecommendedForYouHeroCard extends ConsumerWidget {
  const RecommendedForYouHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickPicksAsync = ref.watch(quickPicksProvider);

    return quickPicksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        final displayTracks = tracks.take(5).toList();
        final featuredTrack = displayTracks.first;

        return _HeroCardLayout(
          featuredTrack: featuredTrack,
          tracks: displayTracks,
        );
      },
      loading: () => const _HeroCardSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HeroCardLayout extends ConsumerWidget {
  final MediaItem featuredTrack;
  final List<MediaItem> tracks;

  const _HeroCardLayout({
    required this.featuredTrack,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recommended for You',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                'Personalized Mix',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isStacked = availableWidth < 500;
              final artSize = isStacked
                  ? 160.0
                  : (availableWidth * 0.33).clamp(110.0, 210.0);

              if (isStacked) {
                return Column(
                  children: [
                    Center(
                      child: _LeftFeaturedArtwork(
                        track: featuredTrack,
                        size: artSize,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: List.generate(tracks.length, (index) {
                        return _HeroTrackRow(
                          track: tracks[index],
                          index: index,
                        );
                      }),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Responsive Square Artwork
                  _LeftFeaturedArtwork(
                    track: featuredTrack,
                    size: artSize,
                  ),

                  const SizedBox(width: 16),

                  // Right Column: 5-Track Interactive List
                  Expanded(
                    child: Column(
                      children: List.generate(tracks.length, (index) {
                        return _HeroTrackRow(
                          track: tracks[index],
                          index: index,
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeftFeaturedArtwork extends ConsumerStatefulWidget {
  final MediaItem track;
  final double size;

  const _LeftFeaturedArtwork({
    required this.track,
    this.size = 210.0,
  });

  @override
  ConsumerState<_LeftFeaturedArtwork> createState() => _LeftFeaturedArtworkState();
}

class _LeftFeaturedArtworkState extends ConsumerState<_LeftFeaturedArtwork> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final trackKey = widget.track.id ?? widget.track.path;

    final (isCurrent, isPlaying, isLoading) = ref.watch(
      audioProvider.select((s) {
        final currentKey = s.currentTrack?.id ?? s.currentTrack?.path;
        final isCurr = currentKey != null && currentKey == trackKey;
        return (isCurr, isCurr && s.isPlaying, isCurr && s.isLoading);
      }),
    );

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!_isHovered) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (_isHovered) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTap: () {
            if (isCurrent) {
              ref.read(audioProvider.notifier).togglePlayPause();
            } else {
              ref.read(audioProvider.notifier).playTrack(widget.track);
            }
          },
          onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
            context: context,
            ref: ref,
            item: widget.track,
            position: details.globalPosition,
          ),
          onLongPress: () => MediaActionUtils.showMediaActions(
            context: context,
            ref: ref,
            item: widget.track,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: MediaArtworkWidget(item: widget.track, width: size, height: size),
                  ),
                ),
                // Play button hover overlay using unified CardHoverPlayButton
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: Center(
                        child: CardHoverPlayButton(
                          isPlaying: isPlaying,
                          isLoading: isLoading,
                          iconSize: widget.size < 140 ? 36.0 : 44.0,
                          onTap: () {
                            if (isCurrent) {
                              ref.read(audioProvider.notifier).togglePlayPause();
                            } else {
                              ref.read(audioProvider.notifier).playTrack(widget.track);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroTrackRow extends ConsumerWidget {
  final MediaItem track;
  final int index;

  const _HeroTrackRow({
    required this.track,
    required this.index,
  });

  String _formatDuration(Duration? d) {
    if (d == null || d.inSeconds <= 0) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackKey = track.id ?? track.path;
    final (isCurrent, isPlaying) = ref.watch(
      audioProvider.select((s) {
        final currentKey = s.currentTrack?.id ?? s.currentTrack?.path;
        final isCurr = currentKey != null && currentKey == trackKey;
        return (isCurr, isCurr && s.isPlaying);
      }),
    );
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final isLiked = ref.watch(
      playlistProvider.select((s) => s.value?.isLiked(track) ?? false),
    );

    return RepaintBoundary(
      child: Material(
        color: isCurrent
            ? primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => ref.read(audioProvider.notifier).playTrack(track),
          onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
            context: context,
            ref: ref,
            item: track,
            position: details.globalPosition,
          ),
          onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: track),
          borderRadius: BorderRadius.circular(12),
          hoverColor: primary.withValues(alpha: 0.08),
          splashFactory: NoSplash.splashFactory,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowWidth = constraints.maxWidth;
              final showDuration = rowWidth > 200;
              final showIndex = rowWidth > 140;

              return Row(
                children: [
                  // Index or wave animation
                  if (showIndex) ...[
                    SizedBox(
                      width: 22,
                      child: isPlaying
                          ? Icon(UIcons.regular.waveform_path, size: 14, color: primary)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isCurrent
                                    ? primary
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Mini cover art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: MediaArtworkWidget(item: track, width: 32, height: 32),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title & Artist with marquee auto-scrolling
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            color: isCurrent
                                ? primary
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Like Heart Toggle using app standard ReusableHoverIconButton
                  ReusableHoverIconButton(
                    icon: isLiked ? UIcons.solid.heart : UIcons.regular.heart,
                    iconSize: 15,
                    padding: 6,
                    iconColor: isLiked ? Colors.redAccent : theme.iconTheme.color!.withValues(alpha: 0.4),
                    tooltip: isLiked ? 'Unlike' : 'Like',
                    onTap: () => ref.read(playlistProvider.notifier).toggleLike(track),
                  ),

                  // Duration
                  if (showDuration) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 38,
                      child: Text(
                        _formatDuration(track.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
    );
  }
}

class _HeroCardSkeleton extends StatelessWidget {
  const _HeroCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerSkeleton(
                width: 170,
                height: 20,
                borderRadius: BorderRadius.circular(5),
              ),
              const Spacer(),
              ShimmerSkeleton(
                width: 90,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isStacked = availableWidth < 500;
              final artSize = isStacked
                  ? 160.0
                  : (availableWidth * 0.33).clamp(110.0, 210.0);

              if (isStacked) {
                return Column(
                  children: [
                    Center(
                      child: ShimmerSkeleton(
                        width: artSize,
                        height: artSize,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: List.generate(4, (index) => const _HeroTrackRowSkeleton()),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(
                    width: artSize,
                    height: artSize,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: List.generate(4, (index) => const _HeroTrackRowSkeleton()),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroTrackRowSkeleton extends StatelessWidget {
  const _HeroTrackRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            ShimmerSkeleton(
              width: 38,
              height: 38,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerSkeleton(
                    width: 140,
                    height: 13,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  ShimmerSkeleton(
                    width: 85,
                    height: 10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ShimmerSkeleton(
              width: 24,
              height: 24,
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
      ),
    );
  }
}
