import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_track_info.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_core_controls.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_extra_actions.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_progress_bar.dart';

// Import NowPlayingScreen notifier (this is typically in the same or separate provider file depending on architecture)
// Since we isolated things, I'll rely on the global navigation or a similar provider.
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:resonance/core/providers/overlay_provider.dart';

class AudioDockedPlayer extends ConsumerWidget {
  const AudioDockedPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTrack = ref.watch(audioProvider.select((s) => s.currentTrack));

    if (displayTrack == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isWide = AppBreakpoints.isWide(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.primaryColor;

    return Padding(
      padding: isWide
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : EdgeInsets.zero,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            ref.read(nowPlayingOverlayProvider.notifier).toggle();
          },
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: isWide ? BorderRadius.circular(22) : BorderRadius.zero,
              boxShadow: isWide
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _DockedControlsBar(
                  track: displayTrack,
                  accent: accent,
                  surfaceColor: theme.colorScheme.surface,
                  isFloating: isWide,
                ),
                const AudioProgressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockedControlsBar extends StatelessWidget {
  final MediaItem track;
  final Color accent;
  final Color surfaceColor;
  final bool isFloating;

  const _DockedControlsBar({
    required this.track,
    required this.accent,
    required this.surfaceColor,
    this.isFloating = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isFloating ? BorderRadius.circular(22) : BorderRadius.zero;

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: isFloating ? 0.94 : 0.98),
            borderRadius: radius,
            border: isFloating
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.0,
                  )
                : Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1.0,
                    ),
                  ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = AppBreakpoints.isWideWidth(constraints.maxWidth);

              return Row(
                children: [
                  // 1. Track Info (Album Art, Artist, Title, Hero Tag)
                  Expanded(
                    flex: 1,
                    child: RepaintBoundary(
                      child: AudioTrackInfo(
                        track: track,
                        isDesktop: isDesktop,
                      ),
                    ),
                  ),

                  // 2. Core Controls & Actions
                  if (isDesktop) ...[
                    Expanded(
                      flex: 1,
                      child: RepaintBoundary(
                        child: AudioCoreControls(isDesktop: isDesktop),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: RepaintBoundary(
                        child: AudioExtraActions(
                          track: track,
                          isDesktop: isDesktop,
                        ),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 12.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            child: AudioCoreControls(isDesktop: false),
                          ),
                          const SizedBox(width: 4),
                          RepaintBoundary(
                            child: AudioExtraActions(
                              track: track,
                              isDesktop: false,
                            ),
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
    );
  }
}




