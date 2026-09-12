import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_track_info.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_core_controls.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_extra_actions.dart';

// Import NowPlayingScreen notifier (this is typically in the same or separate provider file depending on architecture)
// Since we isolated things, I'll rely on the global navigation or a similar provider.
import 'package:resonance/core/domain/models/media_item.dart';
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
              _DockedControlsBar(
                track: displayTrack,
                isHovered: _isHovered,
                accent: accent,
                surfaceColor: theme.colorScheme.surface,
              ),
              _DockedAmbientGlow(
                isHovered: _isHovered,
                accent: accent,
              ),
              const _DockedProgressSlider(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockedControlsBar extends StatelessWidget {
  final MediaItem track;
  final bool isHovered;
  final Color accent;
  final Color surfaceColor;

  const _DockedControlsBar({
    required this.track,
    required this.isHovered,
    required this.accent,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.82),
              border: Border(
                top: BorderSide(
                  color: isHovered
                      ? accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
              gradient: isHovered
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
                final bool isDesktop = AppBreakpoints.isWideWidth(constraints.maxWidth);

                return Row(
                  children: [
                    // 1. Track Info (Album Art, Artist, Title, Hero Tag)
                    Expanded(
                      flex: 1,
                      child: AudioTrackInfo(
                        track: track,
                        isDesktop: isDesktop,
                      ),
                    ),

                    // 2. Core Controls & Actions
                    if (isDesktop) ...[
                      Expanded(
                        flex: 1,
                        child: AudioCoreControls(isDesktop: isDesktop),
                      ),
                      Expanded(
                        flex: 1,
                        child: AudioExtraActions(
                          track: track,
                          isDesktop: isDesktop,
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AudioCoreControls(isDesktop: false),
                            const SizedBox(width: 4),
                            AudioExtraActions(
                              track: track,
                              isDesktop: false,
                            ),
                          ],
                        ),
                      ),
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

class _DockedAmbientGlow extends StatelessWidget {
  final bool isHovered;
  final Color accent;

  const _DockedAmbientGlow({
    required this.isHovered,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 6,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: isHovered ? 1.0 : 0.0,
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
    );
  }
}

class _DockedProgressSlider extends ConsumerWidget {
  const _DockedProgressSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(audioProvider.select((s) => s.position));
    final dur = ref.watch(audioProvider.select((s) => s.duration));

    return Positioned(
      top: -14, // Sets exactly 16px below and 16px above for maximum hit-area comfort
      left: 0,
      right: 0,
      height: 32,
      child: ReusableSeekSlider(
        value: pos.inMilliseconds.toDouble(),
        max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0,
        onChanged: (val) {
          ref.read(audioProvider.notifier).seek(Duration(milliseconds: val.toInt()));
        },
      ),
    );
  }
}

