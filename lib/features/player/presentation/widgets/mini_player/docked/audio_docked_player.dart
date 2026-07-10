import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

import 'package:resonance/core/widgets/reusable_seek_slider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_track_info.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_core_controls.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_extra_actions.dart';

// Import NowPlayingScreen notifier (this is typically in the same or separate provider file depending on architecture)
// Since we isolated things, I'll rely on the global navigation or a similar provider.
import 'package:resonance/features/lyrics/presentation/providers/lyrics_ui_provider.dart';

class AudioDockedPlayer extends ConsumerWidget {
  const AudioDockedPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final displayTrack = audioState.currentTrack;

    if (displayTrack == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        ref.read(nowPlayingOverlayProvider.notifier).toggle();
      },
      child: SizedBox(
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // SOTA V5.1 Layer 1: Background & Controls (Inside ClipRRect)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                      ),
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
            // SOTA V5.1 Layer 2: Floating Seeker (Bebas Melayang di luar 72px boundaries)
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
    );
  }
}
