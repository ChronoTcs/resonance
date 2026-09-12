import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';

import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import '../widgets/player_cards.dart';
import '../widgets/mini_player/shared/audio_settings_sheet.dart';

//  // Unused

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  void _showMediaActions(BuildContext context, dynamic track) {
    MediaActionsBottomSheet.show(
      context: context,
      item: track,
    );
  }

  void _showAudioSettings(BuildContext context) {
    AudioSettingsSheet.show(context);
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OPTIMIZATION: Only watch properties that affect the general layout.
    // Watching the full audioProvider causes rebuilds every second (position change).
    final track = ref.watch(audioProvider.select((s) => s.currentTrack));
    final isAndroid = Platform.isAndroid;
    final blurSigma = isAndroid ? 40.0 : 80.0;

    return PopScope(
      canPop: !isAndroid,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(nowPlayingOverlayProvider.notifier).setVisible(false);
      },
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          _NowPlayingBackground(track: track, blurSigma: blurSigma),
          SafeArea(
            child: Column(
              children: [
                _NowPlayingTopBar(
                  track: track,
                  onClose: () => ref
                      .read(nowPlayingOverlayProvider.notifier)
                      .setVisible(false),
                  onQueue: () => ref
                      .read(queueOverlayProvider.notifier)
                      .toggle(),
                  onMediaActions: () => _showMediaActions(context, track),
                  onAudioSettings: () => _showAudioSettings(context),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: SilkySingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 12,
                        bottom: 48,
                      ),
                      child: track == null
                          ? const Center(child: Text('No media playing'))
                          : Center(
                              child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final totalWidth = constraints.maxWidth;
                                    final isCompactLayout =
                                        AppBreakpoints.isCompactWidth(totalWidth);

                                    return isCompactLayout
                                        ? _MobileLayout(track: track)
                                        : _DesktopLayout(
                                            track: track,
                                            totalWidth: totalWidth,
                                          );
                                  },
                              ),
                            ),
                    ),
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

// ── Extracted Modular Sub-Widgets ─────────────────────────────────────────────

class _NowPlayingBackground extends StatelessWidget {
  final dynamic track;
  final double blurSigma;

  const _NowPlayingBackground({
    required this.track,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Positioned.fill(
              child: track != null
                  ? MediaArtworkWidget(
                      item: track,
                      fit: BoxFit.cover,
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.6),
                      colorBlendMode:
                          isLight ? BlendMode.lighten : BlendMode.darken,
                    )
                  : Container(color: Theme.of(context).colorScheme.surface),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: Container(
                  color: (isLight ? Colors.white : Colors.black)
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingTopBar extends StatelessWidget {
  final dynamic track;
  final VoidCallback onClose;
  final VoidCallback onQueue;
  final VoidCallback onMediaActions;
  final VoidCallback onAudioSettings;

  const _NowPlayingTopBar({
    required this.track,
    required this.onClose,
    required this.onQueue,
    required this.onMediaActions,
    required this.onAudioSettings,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CollapseButton(
            tooltip: 'Close',
            iconSize: 20,
            color: iconColor,
            onTap: onClose,
          ),
          const Spacer(),
          Text(
            'NOW PLAYING',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: iconColor,
            ),
          ),
          const Spacer(),
          ReusableHoverIconButton(
            icon: UIcons.regular.list_music,
            iconSize: 20,
            tooltip: 'Queue',
            color: iconColor,
            onTap: onQueue,
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.add,
            iconSize: 20,
            tooltip: 'Media Actions',
            color: iconColor,
            onTap: onMediaActions,
          ),
          OverflowMenuButton(
            tooltip: 'Audio Settings',
            iconSize: 20,
            color: iconColor,
            onTap: onAudioSettings,
          ),
        ],
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  final dynamic track;

  const _ArtworkCard({required this.track});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Hero(
            tag: 'player_artwork_${track?.id ?? track.hashCode}',
            child: MediaArtworkWidget(item: track),
          ),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final dynamic track;

  const _MobileLayout({required this.track});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArtworkCard(track: track),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 16),
          const NavigationControlCard(),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 24),
        ],
        MetadataCard(track: track),
        const SizedBox(height: 24),
        const MiniLyricsCard(height: 350),
        const SizedBox(height: 24),
        const NextInQueueCard(),
      ],
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final dynamic track;
  final double totalWidth;

  const _DesktopLayout({
    required this.track,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = 32.0;
    final leftWidth = (totalWidth - spacing) * 0.4;
    final gridHeight = leftWidth + 24 + 240;

    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Artwork + Metadata (40%)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArtworkCard(track: track),
                const SizedBox(height: 24),
                SizedBox(
                  height: 240,
                  child: MetadataCard(track: track),
                ),
              ],
            ),
          ),
          const SizedBox(width: spacing),
          // Right Column: Lyrics + Queue (60%)
          const Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: MiniLyricsCard()),
                SizedBox(height: 24),
                NextInQueueCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
