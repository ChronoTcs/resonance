import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' hide VideoState;
import '../../application/video_player_notifier.dart';
import '../../../../core/widgets/seek_slider.dart';
import 'dedicated_fullscreen_video.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';

class DedicatedVideoPlayer extends StatefulWidget {
  const DedicatedVideoPlayer({super.key});

  @override
  State<DedicatedVideoPlayer> createState() => _DedicatedVideoPlayerState();
}

class _DedicatedVideoPlayerState extends State<DedicatedVideoPlayer> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Set active view to full to ensure we get the texture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final container = ProviderScope.containerOf(context);
        container.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.full);
      }
    });
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && !FocusScope.of(context).hasFocus) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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
        final theme = Theme.of(context);

        if (videoState.currentVideo == null) {
          return const Scaffold(body: Center(child: Text('No video selected')));
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _onInteraction(),
            child: GestureDetector(
              onTap: () {
                setState(() => _showControls = !_showControls);
                if (_showControls) _startHideTimer();
              },
              child: Column(
                children: [
                  // 1. Top Bar (Back Button & Title) - Animated Show/Hide
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showControls ? MediaQuery.of(context).padding.top + 60 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
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
                              onPressed: () {
                                videoNotifier.setActiveViewType(VideoPlayerViewType.mini);
                                Navigator.pop(context);
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    videoState.currentVideo!.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (videoState.currentVideo!.artist != null)
                                    Text(
                                      videoState.currentVideo!.artist!,
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Video Area (Background) - Fills remaining space
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      child: videoNotifier.controller != null
                          ? Center(
                              child: videoState.activeViewType == VideoPlayerViewType.full
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

                  // 3. Bottom Controls - Animated Show/Hide
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showControls ? 108 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        height: 108,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Very thin Progress Slider
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              child: SeekSlider(
                                value: videoState.position.inSeconds.toDouble(),
                                max: videoState.duration.inSeconds.toDouble() > 0 
                                    ? videoState.duration.inSeconds.toDouble() 
                                    : 1.0,
                                onChanged: (val) {
                                  videoNotifier.seek(Duration(seconds: val.toInt()));
                                  _onInteraction();
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
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  // Center: Media Controls (Tighter)
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ModernIconButton(
                                          icon: const Icon(Icons.replay_10, size: 22),
                                          onPressed: () {
                                            videoNotifier.jump(const Duration(seconds: -10));
                                            _onInteraction();
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        ModernIconButton(
                                          icon: Icon(
                                            videoState.isPlaying 
                                                ? Icons.pause_circle_filled 
                                                : Icons.play_circle_filled,
                                          ),
                                          iconSize: 42,
                                          color: theme.primaryColor,
                                          onPressed: () {
                                            videoNotifier.togglePlayPause();
                                            _onInteraction();
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        ModernIconButton(
                                          icon: const Icon(Icons.forward_10, size: 22),
                                          onPressed: () {
                                            videoNotifier.jump(const Duration(seconds: 10));
                                            _onInteraction();
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
                                            icon: Icon(Icons.hd_outlined, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                                            onSelected: (track) {
                                              videoNotifier.setVideoTrack(track);
                                              _onInteraction();
                                            },
                                            itemBuilder: (context) => videoState.uniqueVideoTracks.map((track) {
                                              final trackLabel = track.title ?? ((track.h ?? 0) > 0 ? '${track.h}p' : 'Auto');
                                              return PopupMenuItem<VideoTrack>(
                                                value: track,
                                                child: Text(trackLabel),
                                              );
                                            }).toList(),
                                          ),
                                        
                                        // Volume Button
                                        ModernIconButton(
                                          icon: Icon(
                                            videoState.volume == 0
                                                ? Icons.volume_off
                                                : videoState.volume < 0.5
                                                    ? Icons.volume_down
                                                    : Icons.volume_up,
                                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _showVolumeDialog(context, videoState, videoNotifier);
                                            _onInteraction();
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        // Fullscreen
                                        ModernIconButton(
                                          icon: Icon(Icons.fullscreen, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                settings: const RouteSettings(name: '/fullscreen_video'),
                                                builder: (context) => const DedicatedFullscreenVideo(),
                                              ),
                                            );
                                          },
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              bottom: 120,
              right: 24,
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
                        color: theme.colorScheme.surface.withOpacity(0.8),
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
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: theme.primaryColor,
                                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                                      thumbColor: theme.primaryColor,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      trackHeight: 4,
                                      overlayShape: SliderComponentShape.noOverlay,
                                    ),
                                    child: Slider(
                                      value: currentVolume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) => ref.read(videoPlayerProvider.notifier).setVolume(val),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "${(currentVolume * 100).toInt()}",
                                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
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

