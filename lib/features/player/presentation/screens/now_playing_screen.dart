import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/player/application/providers/video_player_notifier.dart' as v;
import '../widgets/player_cards.dart';
import '../widgets/equalizer_sheet.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/collapse_button.dart';
import 'package:resonance/core/widgets/overflow_menu_button.dart';
// import 'package:resonance/core/widgets/hover_widgets.dart'; // Unused

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  void _showMediaActions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(item: track),
    );
  }

  void _showAudioSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Audio Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              // Speed Control
              _buildSettingLabel(context, 'Playback Speed'),
              Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(audioProvider);
                  return _buildSliderRow(
                    context, 
                    '0.5x', 
                    '2.0x', 
                    state.speed, 
                    0.5, 
                    2.0, 
                    15, 
                    (v) => ref.read(audioProvider.notifier).setSpeed(v)
                  );
                },
              ),
              const SizedBox(height: 10),
              // Pitch Control
              _buildSettingLabel(context, 'Pitch'),
              Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(audioProvider);
                  return _buildSliderRow(
                    context, 
                    '-12', 
                    '+12', 
                    state.pitch, 
                    -12.0, 
                    12.0, 
                    24, 
                    (v) => ref.read(audioProvider.notifier).setPitch(v)
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(UIcons.regular.settings_sliders, color: Theme.of(context).colorScheme.onSurface),
                title: const Text('Equalizer Settings'),
                trailing: Icon(UIcons.regular.angle_small_right, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => const EqualizerSheet(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
    );
  }

  Widget _buildSliderRow(BuildContext context, String minLabel, String maxLabel, double value, double min, double max, int divisions, Function(double) onChanged) {
    return Row(
      children: [
        Text(minLabel, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Theme.of(context).primaryColor,
            onChanged: onChanged,
          ),
        ),
        Text(maxLabel, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OPTIMIZATION: Only watch properties that affect the general layout.
    // Watching the full audioProvider causes rebuilds every second (position change).
    final currentTrack = ref.watch(audioProvider.select((s) => s.currentTrack));
    final videoState = ref.watch(v.videoPlayerProvider);
    final isVideo = videoState.currentVideo != null;
    final track = isVideo ? videoState.currentVideo : currentTrack;

    final isAndroid = Platform.isAndroid;
    final blurSigma = isAndroid ? 40.0 : 80.0;

    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        // Dynamic Background (Consistent with FullScreenPlayer)
        // OPTIMIZATION: RepaintBoundary prevents blur from re-calculating during lyrics scroll
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: track != null 
                    ? MediaArtworkWidget(
                        item: track,
                        fit: BoxFit.cover,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.6),
                        colorBlendMode: Theme.of(context).brightness == Brightness.light
                            ? BlendMode.lighten
                            : BlendMode.darken,
                      )
                    : Container(color: Theme.of(context).colorScheme.surface),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: Container(
                      color: (Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : Colors.black)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main Content
        SafeArea(
          child: Column(
            children: [
              // Custom Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CollapseButton(
                      tooltip: 'Tutup',
                      iconSize: 32,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      onTap: () => ref.read(nowPlayingOverlayProvider.notifier).setVisible(false),
                    ),
                    const Spacer(),
                    Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.add,
                      tooltip: 'Media Actions',
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      onTap: () => _showMediaActions(context, track),
                    ),
                    OverflowMenuButton(
                      tooltip: 'Audio Settings',
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      onTap: () => _showAudioSettings(context),
                    ),
                  ],
                ),
              ),

              // Scrollable area for cards
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
                  child: SingleChildScrollView(
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
                                final isMobile = totalWidth < 600;

                                if (isMobile) {
                                  // Mobile Layout: Vertical Stack
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // 1. Square Artwork
                                      AspectRatio(
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
                                              tag: 'player_artwork_${track.id ?? track.hashCode}',
                                              child: MediaArtworkWidget(item: track),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (Platform.isAndroid) ...[
                                        const SizedBox(height: 16),
                                        const NavigationControlCard(),
                                        const SizedBox(height: 16),
                                      ] else ...[
                                        const SizedBox(height: 24),
                                      ],
                                      // 2. Metadata
                                      MetadataCard(track: track),
                                      const SizedBox(height: 24),
                                      // 3. Lyrics: FIXED HEIGHT REQUIRED in ScrollView
                                      const MiniLyricsCard(height: 350),
                                      const SizedBox(height: 24),
                                      // 4. Queue: FIXED HEIGHT REQUIRED in ScrollView
                                      const NextInQueueCard(height: 120),
                                    ],
                                  );
                                }

                                // Desktop Layout: Horizontal Row (Original)
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
                                            // Top: Square Artwork
                                            AspectRatio(
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
                                                    tag: 'player_artwork_${track.id ?? track.hashCode}',
                                                    child: MediaArtworkWidget(item: track),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            // Bottom: Metadata
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
                                            Expanded(
                                              child: MiniLyricsCard(),
                                            ),
                                            SizedBox(height: 24),
                                            NextInQueueCard(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
    );
  }
}
