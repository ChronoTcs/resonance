import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../../../core/widgets/media_artwork_widget.dart';
import 'package:resonance_app/features/player/data/models/player_enums.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../application/audio_provider.dart';
import '../../application/video_player_notifier.dart';
import '../../../lyrics/presentation/providers/lyrics_ui_provider.dart';
import '../../../lyrics/presentation/widgets/lyrics_screen.dart';
import '../../../../core/widgets/seek_slider.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../library/application/library_provider.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/player_cards.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';

class FullScreenPlayer extends ConsumerStatefulWidget {
  const FullScreenPlayer({super.key});

  @override
  ConsumerState<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends ConsumerState<FullScreenPlayer> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleKey);
    _enterFullScreen();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      final showFullLyrics = ref.read(lyricsOverlayProvider);
      if (showFullLyrics) {
        ref.read(lyricsOverlayProvider.notifier).toggle();
      } else {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
      return true; // Mark as handled
    }
    return false;
  }

  Future<void> _enterFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // PREVENT FREEZE: Ensure title bar is normal BEFORE going full screen
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );

      // PREVENT FREEZE: Use addPostFrameCallback to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await windowManager.setFullScreen(true);
        _focusNode.requestFocus();
      });
    }
  }

  Future<void> _exitFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
      // Small delay to let DWM catch up
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _focusNode.dispose();
    _exitFullScreen();
    super.dispose();
  }

  void _showMediaActions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(
        item: track,
        onDelete: track.id == null
            ? () => _confirmDelete(context, track)
            : null,
      ),
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
              Text(
                'Playback Speed',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(audioProvider);
                  return Row(
                    children: [
                      Text(
                        '0.5x',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: state.speed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${state.speed.toStringAsFixed(1)}x',
                          activeColor: Theme.of(context).primaryColor,
                          onChanged: (val) =>
                              ref.read(audioProvider.notifier).setSpeed(val),
                        ),
                      ),
                      Text(
                        '2.0x',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Pitch',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(audioProvider);
                  return Row(
                    children: [
                      Text(
                        '-12',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: state.pitch,
                          min: -12.0,
                          max: 12.0,
                          divisions: 24,
                          label: state.pitch.toStringAsFixed(1),
                          activeColor: Theme.of(context).primaryColor,
                          onChanged: (val) =>
                              ref.read(audioProvider.notifier).setPitch(val),
                        ),
                      ),
                      Text(
                        '+12',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(
                  Icons.equalizer,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: const Text('Equalizer Settings'),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
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
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, dynamic item) {
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Permanently delete "${item.title}" from your device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dlg);
              ref.read(libraryProvider.notifier).deleteTrack(item.path);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${item.title}" deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSurface(WidgetRef ref) {
    final videoController = ref.watch(videoPlayerProvider.notifier).controller;
    if (videoController == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(
          controller: videoController,
          controls: NoVideoControls, // We use our own UI
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Full Screen Player is only available on Windows.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final audioState = ref.watch(audioProvider);
    final currentTrack = audioState.currentTrack;
    final videoState = ref.watch(videoPlayerProvider);
    final isVideo = videoState.currentVideo != null;
    final displayTrack = isVideo ? videoState.currentVideo : currentTrack;

    final showFullLyrics = ref.watch(lyricsOverlayProvider);
    final theme = Theme.of(context);

    // REMOVED Early Return to stabilize MouseTracker hit-testing
    // displayTrack is checked inside components below

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Dynamic Background
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, _) {
                  if (displayTrack == null)
                    return Container(color: Colors.black);
                  return MediaArtworkWidget(
                    item: displayTrack,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.6),
                    colorBlendMode: BlendMode.darken,
                  );
                },
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
            ),

            // Full Lyrics View Overlay
            if (showFullLyrics)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: const LyricsScreen(isEmbedded: true),
                ),
              ),

            // Layout
            if (!showFullLyrics)
              Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          pinned: false,
                          leadingWidth: 200,
                          leading: Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              children: [
                                Text(
                                  'Playing Now',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            ModernIconButton(
                              icon: const Icon(
                                Icons.playlist_add,
                                color: Colors.white70,
                              ),
                              tooltip: 'Media Actions',
                              onPressed: () =>
                                  _showMediaActions(context, displayTrack),
                            ),
                            ModernIconButton(
                              icon: const Icon(
                                Icons.more_horiz,
                                color: Colors.white70,
                              ),
                              tooltip: 'More',
                              onPressed: () => _showAudioSettings(context),
                            ),
                            ModernIconButton(
                              icon: const Icon(
                                Icons.close_fullscreen,
                                color: Colors.white70,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 24,
                            ),
                            child: Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 500,
                                  maxHeight: 500,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 60,
                                          offset: const Offset(0, 30),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: displayTrack == null
                                          ? Container(color: Colors.black26)
                                          : isVideo
                                          ? _buildVideoSurface(ref)
                                          : Hero(
                                              tag:
                                                  'player_artwork_${displayTrack.id ?? displayTrack.hashCode}',
                                              child: MediaArtworkWidget(
                                                item: displayTrack,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          sliver: SliverToBoxAdapter(
                            child: displayTrack == null
                                ? const Center(
                                    child: Text(
                                      'No media playing',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : SizedBox(
                                    height:
                                        420, // Compact height for Full Screen (Metadata 250 + Queue 146 + GAP 24)
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Metadata (Expands to fill the 420px budget and align with lyrics)
                                              Expanded(
                                                child: MetadataCard(
                                                  track: displayTrack,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              // Queue (Stay compact)
                                              const NextInQueueCard(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        // Lyrics (Matches height of Left Column)
                                        const Expanded(
                                          child: MiniLyricsCard(height: 420),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),

                  // Bottom Bar
                  _FullScreenBottomBar(track: displayTrack),
                ],
              ),

            // Esc Overlay
            if (!showFullLyrics)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'To exit full screen, press ',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'Esc',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenBottomBar extends StatelessWidget {
  final dynamic track;
  const _FullScreenBottomBar({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const SizedBox(height: 8, child: _FullScreenProgress()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: MediaArtworkWidget(item: track),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artist ?? 'Artist',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(flex: 1, child: _FullScreenControls()),
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _UtilityButtons(),
                      const SizedBox(width: 8),
                      const Flexible(child: _FullScreenVolumeSlider()),
                      ModernIconButton(
                        icon: const Icon(
                          Icons.fullscreen_exit,
                          size: 20,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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

class _UtilityButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        ModernIconButton(
          icon: const Icon(
            Icons.mic_external_on_outlined,
            size: 20,
            color: Colors.white70,
          ),
          tooltip: 'Lyrics',
          onPressed: () => ref.read(lyricsOverlayProvider.notifier).toggle(),
        ),
      ],
    );
  }
}

class _FullScreenVolumeSlider extends ConsumerStatefulWidget {
  const _FullScreenVolumeSlider();
  @override
  ConsumerState<_FullScreenVolumeSlider> createState() =>
      _FullScreenVolumeSliderState();
}

class _FullScreenVolumeSliderState
    extends ConsumerState<_FullScreenVolumeSlider> {
  double _prevVolume = 50.0;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(audioProvider.select((s) => s.volume));
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ModernIconButton(
            padding: 0,
            icon: Icon(
              v == 0
                  ? Icons.volume_off_outlined
                  : v < 50
                  ? Icons.volume_down_outlined
                  : Icons.volume_up_outlined,
              size: 20,
              color: Colors.white70,
            ),
            onPressed: () {
              if (v > 0) {
                _prevVolume = v;
                ref.read(audioProvider.notifier).setVolume(0);
              } else {
                ref
                    .read(audioProvider.notifier)
                    .setVolume(_prevVolume > 0 ? _prevVolume : 50);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: v,
                min: 0,
                max: 100,
                onChanged: (val) {
                  ref.read(audioProvider.notifier).setVolume(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${v.toInt()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenProgress extends ConsumerWidget {
  const _FullScreenProgress();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioProvider);
    return SeekSlider(
      value: s.position.inSeconds.toDouble(),
      max: s.duration.inSeconds.toDouble() > 0
          ? s.duration.inSeconds.toDouble()
          : 1.0,
      onChanged: (v) =>
          ref.read(audioProvider.notifier).seek(Duration(seconds: v.toInt())),
    );
  }
}

class _FullScreenControls extends ConsumerWidget {
  const _FullScreenControls();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioProvider);
    final n = ref.read(audioProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ModernIconButton(
          icon: Icon(
            Icons.shuffle,
            size: 20,
            color: s.isShuffleEnabled ? colorScheme.primary : Colors.white70,
          ),
          onPressed: n.toggleShuffle,
        ),
        ModernIconButton(
          icon: const Icon(Icons.skip_previous, size: 32, color: Colors.white),
          onPressed: n.skipToPrevious,
        ),
        ModernIconButton(
          icon: Icon(
            s.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 48,
            color: Colors.white,
          ),
          onPressed: n.togglePlayPause,
        ),
        ModernIconButton(
          icon: const Icon(Icons.skip_next, size: 32, color: Colors.white),
          onPressed: n.skipToNext,
        ),
        ModernIconButton(
          icon: Icon(
            s.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
            size: 20,
            color: s.loopMode != LoopMode.off
                ? colorScheme.primary
                : Colors.white70,
          ),
          onPressed: n.cycleLoopMode,
        ),
      ],
    );
  }
}
