import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_track_info.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_core_controls.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_extra_actions.dart';

// Import NowPlayingScreen notifier (this is typically in the same or separate provider file depending on architecture)
// Since we isolated things, I'll rely on the global navigation or a similar provider.
import 'package:resonance/core/providers/overlay_provider.dart';

class AudioDockedPlayer extends ConsumerStatefulWidget {
  const AudioDockedPlayer({super.key});

  @override
  ConsumerState<AudioDockedPlayer> createState() => _AudioDockedPlayerState();
}

class _AudioDockedPlayerState extends ConsumerState<AudioDockedPlayer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final displayTrack = audioState.currentTrack;

    if (displayTrack == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(nowPlayingOverlayProvider.notifier).toggle();
        },
        child: SizedBox(
            height: 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Base Glass & Accent Hover Glow Layer (Full width, right below progress bar)
                Positioned.fill(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.82),
                          border: Border(
                            top: BorderSide(
                              color: _isHovered
                                  ? accent.withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: 1.0,
                            ),
                          ),
                          gradient: _isHovered
                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    accent.withValues(alpha: 0.14),
                                    accent.withValues(alpha: 0.02),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                )
                              : null,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop = constraints.maxWidth > 500;

                            return Row(
                              children: [
                                // 1. Track Info (Album Art, Artist, Title, Hero Tag)
                                Expanded(
                                  flex: 1,
                                  child: AudioTrackInfo(
                                    track: displayTrack,
                                    isDesktop: isDesktop,
                                  ),
                                ),

                                // 2. Core Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                                if (isDesktop)
                                  Expanded(
                                    flex: 1,
                                    child: AudioCoreControls(isDesktop: isDesktop),
                                  )
                                else
                                  AudioCoreControls(isDesktop: isDesktop),

                                // 3. Extra Actions (Volume, Fullscreen, Playlist Add, Settings)
                                if (isDesktop)
                                  Expanded(
                                    flex: 1,
                                    child: AudioExtraActions(
                                      track: displayTrack,
                                      isDesktop: isDesktop,
                                    ),
                                  )
                                else
                                  AudioExtraActions(
                                    track: displayTrack,
                                    isDesktop: isDesktop,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Ambient Accent Glow Line directly beneath the Progress Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 6,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accent.withValues(alpha: 0.45),
                              accent.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Progress Bar / Seek Slider
                Positioned(
                  top: -14, // Sets exactly 16px below and 16px above for maximum hit-area comfort
                  left: 0,
                  right: 0,
                  height: 32,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final pos = ref.watch(audioProvider.select((s) => s.position));
                      final dur = ref.watch(audioProvider.select((s) => s.duration));
                      return ReusableSeekSlider(
                        value: pos.inMilliseconds.toDouble(),
                        max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0,
                        onChanged: (val) {
                          ref.read(audioProvider.notifier).seek(Duration(milliseconds: val.toInt()));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
