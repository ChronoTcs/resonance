import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit_video/media_kit_video.dart' hide VideoState;
import '../../application/video_player_notifier.dart';
import '../../../../core/widgets/seek_slider.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';

class DedicatedFullscreenVideo extends StatefulWidget {
  const DedicatedFullscreenVideo({super.key});

  @override
  State<DedicatedFullscreenVideo> createState() => _DedicatedFullscreenVideoState();
}

class _DedicatedFullscreenVideoState extends State<DedicatedFullscreenVideo> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
    
    // Set active view to fullscreen and delay window mutation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final container = ProviderScope.containerOf(context);
        container.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.fullscreen);
        _enterFullScreen();
      }
    });
    
    _startHideTimer();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (mounted) _handlePop();
      return true;
    }
    return false;
  }

  bool _isExiting = false;

  Future<void> _handlePop() async {
    if (_isExiting) return;
    _isExiting = true;
    
    // 1. Exit fullscreen first
    await _exitFullScreen();
    
    // 2. Small delay for DWM to normalize
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return;
    
    // 3. Revert active view and pop
    final container = ProviderScope.containerOf(context);
    container.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.full);
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

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onPointerMove(PointerEvent event) {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _hideTimer?.cancel();
    if (!_isExiting) {
      _exitFullScreen();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final videoState = ref.watch(videoPlayerProvider);
        final videoNotifier = ref.read(videoPlayerProvider.notifier);

        return Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
            onHover: (_) => _onPointerMove(const PointerMoveEvent()),
            onExit: (_) => _startHideTimer(),
            child: GestureDetector(
              onTap: () {
                setState(() => _showControls = !_showControls);
                if (_showControls) _startHideTimer();
              },
              child: Column(
                children: [
                  // 1. Top Bar - Thinner, only shown when _showControls is true
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showControls ? MediaQuery.of(context).padding.top + 50 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).padding.top + 50,
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          border: Border(
                            bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            ModernIconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              onPressed: () => _handlePop(),
                            ),
                            Expanded(
                              child: Text(
                                videoState.currentVideo?.title ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Video Output - Fills remaining space
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      child: videoNotifier.controller != null
                          ? Center(
                              child: videoState.activeViewType == VideoPlayerViewType.fullscreen
                                  ? Hero(
                                      tag: 'video_player_surface',
                                      child: Video(
                                        controller: videoNotifier.controller!,
                                        controls: NoVideoControls,
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  // 3. Bottom Controls - Thinner, only shown when _showControls is true
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showControls ? 108 : 0, // Increased height to prevent overflow
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        height: 108,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border(
                            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Progress
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              child: SeekSlider(
                                value: videoState.position.inSeconds.toDouble(),
                                max: videoState.duration.inSeconds.toDouble() > 0 
                                    ? videoState.duration.inSeconds.toDouble() 
                                    : 1.0,
                                onChanged: (val) {
                                  videoNotifier.seek(Duration(seconds: val.toInt()));
                                  _startHideTimer();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Row(
                                children: [
                                  // Left: Duration
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "${_formatDuration(videoState.position)} / ${_formatDuration(videoState.duration)}",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  // Center: Playback Controls (Tighter)
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ModernIconButton(
                                          tooltip: 'Skip Back 10s',
                                          icon: const Icon(Icons.replay_10, size: 24, color: Colors.white),
                                          onPressed: () {
                                            videoNotifier.jump(const Duration(seconds: -10));
                                            _startHideTimer();
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        ModernIconButton(
                                          icon: Icon(
                                            videoState.isPlaying 
                                                ? Icons.pause_circle_filled 
                                                : Icons.play_circle_filled,
                                          ),
                                          iconSize: 48,
                                          color: Colors.white,
                                          onPressed: () {
                                            videoNotifier.togglePlayPause();
                                            _startHideTimer();
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        ModernIconButton(
                                          tooltip: 'Skip Forward 10s',
                                          icon: const Icon(Icons.forward_10, size: 24, color: Colors.white),
                                          onPressed: () {
                                            videoNotifier.jump(const Duration(seconds: 10));
                                            _startHideTimer();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right: Actions
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Quality Selector
                                        if (videoState.uniqueVideoTracks.length > 1 && 
                                            (videoState.currentVideo?.path.startsWith('http') ?? false))
                                          PopupMenuButton<VideoTrack>(
                                            tooltip: 'Quality',
                                            icon: const Icon(Icons.hd_outlined, color: Colors.white, size: 20),
                                            onSelected: (track) {
                                              videoNotifier.setVideoTrack(track);
                                              _startHideTimer();
                                            },
                                            itemBuilder: (context) => videoState.uniqueVideoTracks.map((track) {
                                              final trackLabel = track.title ?? ((track.h ?? 0) > 0 ? '${track.h}p' : 'Auto');
                                              return PopupMenuItem<VideoTrack>(
                                                value: track,
                                                child: Text(trackLabel),
                                              );
                                            }).toList(),
                                          ),
                                        
                                        // Volume
                                        ModernIconButton(
                                          tooltip: 'Volume',
                                          icon: Icon(
                                            videoState.volume == 0
                                                ? Icons.volume_off
                                                : videoState.volume < 0.5
                                                    ? Icons.volume_down
                                                    : Icons.volume_up,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          onPressed: () => _showVolumeDialog(context, videoState, videoNotifier),
                                        ),
                                        const SizedBox(width: 8),
                                        ModernIconButton(
                                          tooltip: 'Exit Fullscreen',
                                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 24),
                                          onPressed: () => _handlePop(),
                                        ),
                                      ],
                                    ),
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
            ),
          ),
        );
      },
    );
  }

  void _showVolumeDialog(BuildContext context, VideoState videoState, VideoPlayerNotifier videoNotifier) {
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
                      width: 300,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                                      thumbColor: Colors.white,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      trackHeight: 4,
                                      overlayShape: SliderComponentShape.noOverlay,
                                    ),
                                    child: Slider(
                                      value: currentVolume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) {
                                        ref.read(videoPlayerProvider.notifier).setVolume(val);
                                        _startHideTimer();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "${(currentVolume * 100).toInt()}",
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
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

