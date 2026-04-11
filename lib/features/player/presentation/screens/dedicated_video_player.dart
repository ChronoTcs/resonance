import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' hide VideoState;
import '../../application/providers/video_player_notifier.dart';
import 'package:resonance_app/core/utils/formatters.dart';
import 'package:resonance_app/core/widgets/reusable_seek_slider.dart';
import '../notifiers/player_ui_controller.dart';
import 'dedicated_fullscreen_video.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';

class DedicatedVideoPlayer extends ConsumerStatefulWidget {
  const DedicatedVideoPlayer({super.key});

  @override
  ConsumerState<DedicatedVideoPlayer> createState() => _DedicatedVideoPlayerState();
}

class _DedicatedVideoPlayerState extends ConsumerState<DedicatedVideoPlayer> {
  @override
  void initState() {
    super.initState();
    // Set active view to full to ensure we get the texture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(videoPlayerProvider.notifier).setActiveViewType(VideoPlayerViewType.full);
        
        // Initial show controls based on current playback state
        final isPlaying = ref.read(videoPlayerProvider.select((s) => s.isPlaying));
        ref.read(playerUIProvider.notifier).show(isPlaying);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Video Player'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.computer, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Video Player is only supported on Windows.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
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

    if (videoState.currentVideo == null) {
      return const Scaffold(body: Center(child: Text('No video selected')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying),
        child: GestureDetector(
          onTap: () => ref.read(playerUIProvider.notifier).toggle(videoState.isPlaying),
          child: Stack(
            children: [
              // 1. Video Surface (Background)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: videoNotifier.controller != null
                      ? Center(
                          child: videoState.activeViewType == VideoPlayerViewType.full
                              ? Video(
                                  controller: videoNotifier.controller!,
                                  controls: NoVideoControls,
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),

              // 2. Overlay Layer (Controls)
              Column(
                children: [
                  // Top Bar (Back Button & Title)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: showControls ? MediaQuery.of(context).padding.top + 60 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          border: Border(
                            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            ReusableHoverIconButton(
                              icon: Icons.arrow_back,
                              color: Colors.white,
                              iconSize: 20,
                              tooltip: 'Back',
                              onTap: () {
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
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
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

                  const Spacer(),

                  // Bottom Controls
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: showControls ? 108 : 0,
                    curve: Curves.easeOutCubic,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        height: 108,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          border: Border(
                            top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Seek Slider
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              child: ReusableSeekSlider(
                                value: videoState.position.inSeconds.toDouble(),
                                max: videoState.duration.inSeconds.toDouble() > 0 
                                    ? videoState.duration.inSeconds.toDouble() 
                                    : 1.0,
                                onChanged: (val) {
                                  videoNotifier.seek(Duration(seconds: val.toInt()));
                                  ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
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
                                      "${AppFormatters.formatDuration(videoState.position)} / ${AppFormatters.formatDuration(videoState.duration)}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  // Center: Control Buttons
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ReusableHoverIconButton(
                                          icon: Icons.replay_10,
                                          iconSize: 22,
                                          tooltip: 'Skip Back 10s',
                                          color: Colors.white,
                                          onTap: () {
                                            videoNotifier.jump(const Duration(seconds: -10));
                                            ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        ReusableHoverIconButton(
                                          tooltip: videoState.isPlaying ? 'Pause' : 'Play',
                                          icon: videoState.isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_filled,
                                          iconSize: 42,
                                          color: theme.primaryColor,
                                          onTap: () {
                                            videoNotifier.togglePlayPause();
                                            ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        ReusableHoverIconButton(
                                          icon: Icons.forward_10,
                                          iconSize: 22,
                                          tooltip: 'Skip Forward 10s',
                                          color: Colors.white,
                                          onTap: () {
                                            videoNotifier.jump(const Duration(seconds: 10));
                                            ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right: Action Buttons
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (videoState.uniqueVideoTracks.length > 1 && 
                                            (videoState.currentVideo?.path.startsWith('http') ?? false))
                                          PopupMenuButton<VideoTrack>(
                                            tooltip: 'Quality',
                                            icon: const Icon(Icons.hd_outlined, color: Colors.white70, size: 20),
                                            onSelected: (track) {
                                              videoNotifier.setVideoTrack(track);
                                              ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                            },
                                            itemBuilder: (context) => videoState.uniqueVideoTracks.map((track) {
                                              final trackLabel = track.title ?? ((track.h ?? 0) > 0 ? '${track.h}p' : 'Auto');
                                              return PopupMenuItem<VideoTrack>(
                                                value: track,
                                                child: Text(trackLabel),
                                              );
                                            }).toList(),
                                          ),
                                        
                                        ReusableHoverIconButton(
                                          icon: videoState.volume == 0
                                              ? Icons.volume_off
                                              : videoState.volume < 0.5
                                                  ? Icons.volume_down
                                                  : Icons.volume_up,
                                          iconSize: 20,
                                          tooltip: 'Volume',
                                          color: Colors.white70,
                                          onTap: () {
                                            _showVolumeDialog(context, videoState, videoNotifier);
                                            ref.read(playerUIProvider.notifier).onInteraction(videoState.isPlaying);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ReusableHoverIconButton(
                                          icon: Icons.fullscreen,
                                          iconSize: 20,
                                          tooltip: 'Fullscreen',
                                          color: Colors.white70,
                                          onTap: () {
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
                        color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: theme.primaryColor,
                                      inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
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
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    "${(currentVolume * 100).toInt()}%",
                                    softWrap: false,
                                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
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
