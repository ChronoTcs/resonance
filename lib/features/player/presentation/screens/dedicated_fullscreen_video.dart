import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit_video/media_kit_video.dart' hide VideoState;
import 'package:resonance_app/core/utils/uicons.dart';
import '../../application/providers/video_player_notifier.dart';
import 'package:resonance_app/core/utils/formatters.dart';
import 'package:resonance_app/core/widgets/reusable_seek_slider.dart';
import '../notifiers/player_ui_controller.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';

class DedicatedFullscreenVideo extends ConsumerStatefulWidget {
  const DedicatedFullscreenVideo({super.key});

  @override
  ConsumerState<DedicatedFullscreenVideo> createState() => _DedicatedFullscreenVideoState();
}

class _DedicatedFullscreenVideoState extends ConsumerState<DedicatedFullscreenVideo> {
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
    
    // Delay attaching the native texture until the window manager has completed its resize
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // 1. Tell OS to enter fullscreen
      await _enterFullScreen();
      
      // 2. Wait for DWM to finish drawing the expanded window
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      // 3. ONLY THEN attach the native texture (prevents freeze)
      ref.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.fullscreen);
      
      // 4. Initial show controls based on current playback state
      final isPlaying = ref.read(videoPlayerProvider.select((s) => s.isPlaying));
      ref.read(playerUIProvider.notifier).show(isPlaying);
    });
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (mounted) _handlePop();
      return true;
    }
    return false;
  }

  Future<void> _handlePop() async {
    if (_isExiting) return;
    _isExiting = true;
    
    // 1. Detach texture to prevent native crash during resize
    ref.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.none);
    
    // 2. Exit fullscreen first
    await _exitFullScreen();
    
    // 3. Small delay for DWM to normalize
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    // 4. Mount back to normal view and pop
    ref.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.full);
    Navigator.pop(context);
  }

  Future<void> _enterFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(true);
    }
  }

  Future<void> _exitFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
      // Small delay to let DWM (Desktop Window Manager) normalize
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    if (!_isExiting) {
      _exitFullScreen();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(UIcons.regular.computer, size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Fullscreen Video is only supported on Windows.',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final showControls = ref.watch(playerUIProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        cursor: showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: (_) => ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying),
        onExit: (_) => ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying),
        child: GestureDetector(
          onTap: () => ref.read(playerUIProvider.notifier).toggle(videoState.isPlaying),
          child: Stack(
            children: [
              // 1. Video Surface (Background)
              Positioned.fill(
                child: Center(
                  child: videoNotifier.controller != null
                      ? Video(
                          controller: videoNotifier.controller!,
                          controls: NoVideoControls,
                        )
                      : const CircularProgressIndicator(),
                ),
              ),

              // 2. Overlay Layer (Controls)
              Column(
                children: [
                  // Top Bar (Exit Button & Title)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: showControls ? 80 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        height: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    videoState.currentVideo?.title ?? 'Full Screen Video',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (videoState.currentVideo?.artist != null)
                                    Text(
                                      videoState.currentVideo!.artist!,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            ReusableHoverIconButton(
                              icon: UIcons.regular.cross_small,
                              color: Colors.white,
                              iconSize: 24,
                              tooltip: 'Exit Fullscreen',
                              onTap: _handlePop,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom Controls
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: showControls ? 120 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Progress bar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: ReusableSeekSlider(
                                value: videoState.position.inMilliseconds.toDouble(),
                                max: videoState.duration.inMilliseconds.toDouble() > 0 
                                    ? videoState.duration.inMilliseconds.toDouble() 
                                    : 1.0,
                                onChanged: (val) {
                                  videoNotifier.seek(Duration(milliseconds: val.toInt()));
                                  ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                              child: Row(
                                children: [
                                  // Duration
                                  Text(
                                    "${AppFormatters.formatDuration(videoState.position)} / ${AppFormatters.formatDuration(videoState.duration)}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  const Spacer(),
                                  // Media Controls
                                  ReusableHoverIconButton(
                                    icon: UIcons.regular.rotate_left,
                                    iconSize: 28,
                                    tooltip: 'Skip back 10s',
                                    color: Colors.white,
                                    onTap: () {
                                      videoNotifier.jump(const Duration(seconds: -10));
                                      ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                    },
                                  ),
                                  const SizedBox(width: 24),
                                  ReusableHoverIconButton(
                                    icon: videoState.isPlaying 
                                        ? UIcons.solid.pause_circle 
                                        : UIcons.solid.play_circle,
                                    iconSize: 56,
                                    tooltip: videoState.isPlaying ? 'Pause' : 'Play',
                                    color: theme.primaryColor,
                                    onTap: () {
                                      videoNotifier.togglePlayPause();
                                      ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                    },
                                  ),
                                  const SizedBox(width: 24),
                                  ReusableHoverIconButton(
                                    icon: UIcons.regular.rotate_right,
                                    iconSize: 28,
                                    tooltip: 'Skip forward 10s',
                                    color: Colors.white,
                                    onTap: () {
                                      videoNotifier.jump(const Duration(seconds: 10));
                                      ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                    },
                                  ),
                                  const Spacer(),
                                  // Volume / Other actions
                                  ReusableHoverIconButton(
                                    icon: videoState.volume == 0
                                        ? UIcons.regular.volume_off
                                        : videoState.volume < 0.5
                                            ? UIcons.regular.volume_down
                                            : UIcons.regular.volume,
                                    iconSize: 24,
                                    tooltip: 'Volume',
                                    color: Colors.white70,
                                    onTap: () {
                                      _showVolumeDialog(context, videoState, videoNotifier);
                                      ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVolumeDialog(BuildContext context, VideoState videoState, VideoPlayerNotifier videoNotifier) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              bottom: 140,
              right: 48,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 320,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final currentVolume = ref.watch(videoPlayerProvider.select((s) => s.volume));
                            return Row(
                              children: [
                                Icon(
                                  currentVolume == 0
                                      ? Icons.volume_off
                                      : currentVolume < 0.5
                                          ? Icons.volume_down
                                          : Icons.volume_up,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: theme.primaryColor,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: theme.primaryColor,
                                      trackHeight: 4,
                                    ),
                                    child: Slider(
                                      value: currentVolume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) => ref.read(videoPlayerProvider.notifier).setVolume(val),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    "${(currentVolume * 100).toInt()}%",
                                    softWrap: false,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
