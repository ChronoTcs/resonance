import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

/// Floating Now Playing Hero Card displayed at the top of mobile home feed.
class MobileNowPlayingHeroCard extends ConsumerWidget {
  const MobileNowPlayingHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(audioProvider.select((s) => s.currentTrack));
    if (track == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
    final isLoading = ref.watch(audioProvider.select((s) => s.isLoading));
    final isPreviousDisabled =
        ref.watch(audioProvider.select((s) => s.currentIndex <= 0));
    final isNextDisabled = ref.watch(audioProvider.select(
      (s) => s.currentIndex >= s.queue.length - 1,
    ));

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;
    final audioNotifier = ref.read(audioProvider.notifier);

    final isLiked = ref.watch(
      playlistProvider.select((s) => s.value?.isLiked(track) ?? false),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(nowPlayingOverlayProvider.notifier).setVisible(true);
        },
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.15 : 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isLight ? 0.12 : 0.18),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // 1. Full-bleed Artwork backdrop
                Positioned.fill(
                  child: MediaArtworkWidget(
                    item: track,
                    width: 400,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),

                // 2. Clean neutral gradient scrim for artwork legibility
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Card Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top: Now Playing badge (erased redundant circle arrow up)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.5,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                UIcons.solid.waveform_path,
                                size: 11,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Middle: Track title and artist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.artist ?? 'Unknown Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Progress line with subtle primary accent touch
                    RepaintBoundary(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final posSec = ref.watch(
                            audioProvider.select((s) => s.position.inSeconds),
                          );
                          final durSec = ref.watch(
                            audioProvider.select((s) => s.duration.inSeconds),
                          );
                          final progress = durSec > 0
                              ? (posSec / durSec).clamp(0.0, 1.0)
                              : 0.0;
                          return LinearProgressIndicator(
                            value: progress,
                            minHeight: 2.5,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            valueColor: AlwaysStoppedAnimation<Color>(primary),
                          );
                        },
                      ),
                    ),

                    // Bottom: Clean dark control strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.10),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Like / Favorite
                              ReusableHoverIconButton(
                                icon: isLiked
                                    ? UIcons.solid.heart
                                    : UIcons.regular.heart,
                                tooltip: isLiked ? 'Unlike' : 'Like',
                                iconSize: 20,
                                padding: 8,
                                color: isLiked
                                    ? Colors.redAccent
                                    : Colors.white.withValues(alpha: 0.90),
                                iconColor: isLiked ? Colors.redAccent : null,
                                onTap: () {
                                  ref
                                      .read(playlistProvider.notifier)
                                      .toggleLike(track);
                                },
                              ),

                              // Previous
                              ReusableHoverIconButton(
                                icon: UIcons.regular.step_backward,
                                tooltip: 'Previous',
                                iconSize: 22,
                                padding: 8,
                                isDisabled: isPreviousDisabled,
                                color: Colors.white,
                                onTap: isPreviousDisabled
                                    ? null
                                    : audioNotifier.skipToPrevious,
                              ),

                              // Center Play / Pause with unified PlayPauseButton
                              PlayPauseButton(
                                isPlaying: isPlaying,
                                isLoading: isLoading,
                                size: PlayPauseSize.medium,
                                color: primary,
                                iconColor: Colors.white,
                                onTap: audioNotifier.togglePlayPause,
                              ),

                              // Next
                              ReusableHoverIconButton(
                                icon: UIcons.regular.step_forward,
                                tooltip: 'Next',
                                iconSize: 22,
                                padding: 8,
                                isDisabled: isNextDisabled,
                                color: Colors.white,
                                onTap: isNextDisabled
                                    ? null
                                    : audioNotifier.skipToNext,
                              ),

                              // Open Now Playing Expand Button
                              ReusableHoverIconButton(
                                icon: UIcons.regular.expand,
                                tooltip: 'Full Player',
                                iconSize: 18,
                                padding: 8,
                                color: Colors.white.withValues(alpha: 0.90),
                                onTap: () {
                                  ref
                                      .read(nowPlayingOverlayProvider.notifier)
                                      .setVisible(true);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
