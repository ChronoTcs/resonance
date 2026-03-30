import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/audio_provider.dart';
import '../../application/video_player_notifier.dart' as v;
import '../../data/models/player_enums.dart';
import 'package:media_kit_video/media_kit_video.dart' hide VideoState;
import 'package:resonance_app/core/widgets/hover_widgets.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/library/application/library_provider.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../../core/widgets/media_artwork_widget.dart';
import '../../../../core/widgets/seek_slider.dart';
import '../../../lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance_app/core/providers/navigation_provider.dart';
import '../screens/full_screen_player.dart';
import '../screens/dedicated_video_player.dart';
import 'equalizer_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({Key? key}) : super(key: key);

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

  Widget _buildVideoSurface(WidgetRef ref) {
    final videoState = ref.watch(v.videoPlayerProvider);
    final videoController = ref.watch(v.videoPlayerProvider.notifier).controller;
    
    if (videoController == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.black,
        child: videoState.activeViewType == v.VideoPlayerViewType.mini
            ? AspectRatio(
                aspectRatio: 1,
                child: Hero(
                  tag: 'video_player_surface',
                  child: Video(
                    controller: videoController,
                    controls: NoVideoControls,
                  ),
                ),
              )
            : const Center(
                child: Icon(Icons.video_library, color: Colors.white24, size: 20),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final videoState = ref.watch(v.videoPlayerProvider);
    final isVideo = videoState.currentVideo != null;
    final currentTrack = audioState.currentTrack;
    
    if (isVideo) {
      return _buildVideoMiniPlayer(context, ref, videoState);
    }

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    return _buildAudioMiniPlayer(context, ref, audioState);
  }

  Widget _buildVideoMiniPlayer(BuildContext context, WidgetRef ref, v.VideoState videoState) {
    final theme = Theme.of(context);
    final videoNotifier = ref.read(v.videoPlayerProvider.notifier);
    final displayTrack = videoState.currentVideo!;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/dedicated_video'),
            builder: (context) => const DedicatedVideoPlayer(),
          ),
        );
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.8),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Seekbar
                SizedBox(
                  height: 4,
                  child: SeekSlider(
                    value: videoState.position.inSeconds.toDouble(),
                    max: videoState.duration.inSeconds.toDouble() > 0 
                        ? videoState.duration.inSeconds.toDouble() 
                        : 1.0,
                    onChanged: (val) {
                      videoNotifier.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildVideoSurface(ref),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTrack.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                displayTrack.artist ?? 'Online Video',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        ModernIconButton(
                          icon: const Icon(Icons.replay_10),
                          iconSize: 24,
                          onPressed: () => videoNotifier.jump(const Duration(seconds: -10)),
                        ),
                        ModernIconButton(
                            icon: Icon(
                              videoState.isPlaying 
                                  ? Icons.pause_circle_filled 
                                  : Icons.play_circle_filled,
                            ),
                            iconSize: 32,
                            color: theme.primaryColor,
                            onPressed: () => videoNotifier.togglePlayPause(),
                          ),
                        ModernIconButton(
                          icon: const Icon(Icons.forward_10),
                          iconSize: 24,
                          onPressed: () => videoNotifier.jump(const Duration(seconds: 10)),
                        ),
                          Builder(
                            builder: (buttonContext) {
                              return ModernIconButton(
                                tooltip: 'Volume',
                                icon: Icon(
                                  videoState.volume == 0
                                      ? Icons.volume_off
                                      : videoState.volume < 0.5
                                          ? Icons.volume_down
                                          : Icons.volume_up,
                                ),
                                iconSize: 20,
                                onPressed: () {
                                  final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
                                  final offset = renderBox.localToGlobal(Offset.zero);
                                  final buttonSize = renderBox.size;
                                  
                                  showDialog(
                                    context: context,
                                    useSafeArea: false,
                                    builder: (context) {
                                      const double dialogWidth = 300;
                                      const double dialogHeight = 64;

                                      double left = offset.dx - (dialogWidth / 2) + (buttonSize.width / 2);
                                      final screenWidth = MediaQuery.of(context).size.width;
                                      if (left < 16) left = 16;
                                      if (left + dialogWidth > screenWidth - 16) {
                                        left = screenWidth - dialogWidth - 16;
                                      }

                                      double top = offset.dy - dialogHeight - 16;

                                      return Stack(
                                        children: [
                                          Positioned(
                                            left: left,
                                            top: top,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                                  child: Container(
                                                    width: dialogWidth,
                                                    height: dialogHeight,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.surface.withOpacity(0.8),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: Colors.white.withOpacity(0.1),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                      child: Consumer(
                                                        builder: (context, ref, _) {
                                                          // Re-watch for real-time updates during drag
                                                          final currentVolume = ref.watch(v.videoPlayerProvider.select((s) => s.volume));
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
                                                                    onChanged: (val) => ref.read(v.videoPlayerProvider.notifier).setVolume(val),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 12),
                                                              SizedBox(
                                                                width: 28,
                                                                child: Text(
                                                                  "${(currentVolume * 100).toInt()}",
                                                                  style: TextStyle(
                                                                    color: theme.colorScheme.onSurface,
                                                                    fontSize: 13,
                                                                  ),
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
                                },
                              );
                            },
                          ),
                          ModernIconButton(
                            icon: const Icon(Icons.close),
                            iconSize: 20,
                            onPressed: () => videoNotifier.closeVideo(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMiniPlayer(BuildContext context, WidgetRef ref, dynamic audioState) {
    final theme = Theme.of(context);
    final displayTrack = audioState.currentTrack!;
    return GestureDetector(
      onTap: () {
        ref.read(nowPlayingOverlayProvider.notifier).toggle();
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.8),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
              ),
            ),
            child: Column(
              children: [
            // Seekbar
            Consumer(
              builder: (context, ref, _) {
                final pos = ref.watch(audioProvider.select((s) => s.position));
                final dur = ref.watch(audioProvider.select((s) => s.duration));
                return SizedBox(
                  height: 10,
                  child: SeekSlider(
                    value: pos.inSeconds.toDouble(),
                    max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                    onChanged: (val) {
                      ref.read(audioProvider.notifier).seek(Duration(seconds: val.toInt()));
                    },
                  ),
                );
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth > 500;

                  return Row(
                    children: [
                      // Album Art
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Hero(
                          tag: 'mini_artwork_${displayTrack.id ?? displayTrack.hashCode}',
                          child: MediaArtworkWidget(
                            item: displayTrack,
                            width: 48,
                            height: 48,
                            borderRadius: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Track Info
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTrack.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              displayTrack.artist ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isDesktop)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final pos = ref.watch(audioProvider.select((s) => s.position));
                                    final dur = ref.watch(audioProvider.select((s) => s.duration));
                                    return Text(
                                      "${_formatDuration(pos)} / ${_formatDuration(dur)}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Core Controls
                      if (isDesktop)
                        Expanded(
                          flex: 1,
                          child: Consumer(
                            builder: (context, ref, _) {
                              final isShuffle = ref.watch(audioProvider.select((s) => s.isShuffleEnabled));
                              final isLoading = ref.watch(audioProvider.select((s) => s.isLoading));
                              final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
                              final loopMode = ref.watch(audioProvider.select((s) => s.loopMode));
                              final notifier = ref.read(audioProvider.notifier);

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ModernIconButton(
                                    tooltip: 'Shuffle',
                                    icon: Icon(
                                      Icons.shuffle,
                                      color: isShuffle
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).iconTheme.color?.withOpacity(0.5),
                                    ),
                                    iconSize: 20,
                                    onPressed: () => notifier.toggleShuffle(),
                                  ),
                                  ModernIconButton(
                                    tooltip: 'Previous',
                                    icon: const Icon(Icons.skip_previous),
                                    iconSize: 24,
                                    onPressed: () => notifier.skipToPrevious(),
                                  ),
                                  isLoading
                                      ? SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        )
                                      : ModernIconButton(
                                          tooltip: isPlaying ? 'Pause' : 'Play',
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_filled,
                                          ),
                                          iconSize: 36,
                                          color: Theme.of(context).primaryColor,
                                          onPressed: () => notifier.togglePlayPause(),
                                        ),
                                  ModernIconButton(
                                    tooltip: 'Next',
                                    icon: const Icon(Icons.skip_next),
                                    iconSize: 24,
                                    onPressed: () => notifier.skipToNext(),
                                  ),
                                  ModernIconButton(
                                    tooltip: loopMode == LoopMode.off 
                                        ? 'Repeat Off' 
                                        : loopMode == LoopMode.one 
                                            ? 'Repeat One' 
                                            : 'Repeat All',
                                    icon: Icon(
                                      loopMode == LoopMode.one
                                          ? Icons.repeat_one
                                          : Icons.repeat,
                                      color: loopMode == LoopMode.off
                                          ? Theme.of(context).iconTheme.color?.withOpacity(0.5)
                                          : Theme.of(context).primaryColor,
                                    ),
                                    iconSize: 20,
                                    onPressed: () => notifier.cycleLoopMode(),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      else
                        Consumer(
                          builder: (context, ref, _) {
                            final isLoading = ref.watch(audioProvider.select((s) => s.isLoading));
                            final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
                            final notifier = ref.read(audioProvider.notifier);
                            
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isLoading
                                    ? SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      )
                                    : ModernIconButton(
                                        tooltip: isPlaying ? 'Pause' : 'Play',
                                        icon: Icon(
                                          isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_filled,
                                        ),
                                        iconSize: 36,
                                        color: Theme.of(context).primaryColor,
                                        onPressed: () => notifier.togglePlayPause(),
                                      ),
                                ModernIconButton(
                                  tooltip: 'Next',
                                  icon: const Icon(Icons.skip_next),
                                  iconSize: 24,
                                  onPressed: () => notifier.skipToNext(),
                                ),
                              ],
                            );
                          },
                        ),
                      if (!isDesktop)
                        ModernIconButton(
                          icon: const Icon(Icons.playlist_add),
                          iconSize: 20,
                          tooltip: 'Media actions',
                          onPressed: () => _showMediaActions(
                            context,
                            ref,
                            displayTrack,
                          ),
                        ),


                      // Extra actions - Only visible on wide screens
                      if (isDesktop)
                        Expanded(
                          flex: 1,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                              ModernIconButton(
                                icon: const Icon(Icons.playlist_add),
                                iconSize: 20,
                                tooltip: 'Media actions',
                                onPressed: () => _showMediaActions(
                                  context,
                                  ref,
                                  displayTrack,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Consumer(
                                builder: (context, ref, _) {
                                  final pos = ref.watch(audioProvider.select((s) => s.position));
                                  final dur = ref.watch(audioProvider.select((s) => s.duration));
                                  return SizedBox(
                                    width: 110, // Fixed width to prevent jitter
                                    child: Text(
                                      "${_formatDuration(pos)} / ${_formatDuration(dur)}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (buttonContext) {
                                  return ModernIconButton(
                                    tooltip: 'Volume',
                                    icon: Consumer(
                                      builder: (context, ref, _) {
                                        final v = ref.watch(audioProvider.select((s) => s.volume));
                                        return Icon(
                                          v == 0
                                              ? Icons.volume_off
                                              : v < 50
                                              ? Icons.volume_down
                                              : Icons.volume_up,
                                        );
                                      },
                                    ),
                                    onPressed: () {
                                      final RenderBox renderBox =
                                          buttonContext.findRenderObject()
                                              as RenderBox;
                                      final offset = renderBox.localToGlobal(
                                        Offset.zero,
                                      );
                                      final buttonSize = renderBox.size;

                                      showDialog(
                                        context: context,
                                        useSafeArea: false,
                                        builder: (context) {
                                          const double dialogWidth = 300;
                                          const double dialogHeight = 64;

                                          double left =
                                              offset.dx -
                                              (dialogWidth / 2) +
                                              (buttonSize.width / 2);
                                          final screenWidth = MediaQuery.of(
                                            context,
                                          ).size.width;
                                          if (left < 16) left = 16;
                                          if (left + dialogWidth >
                                              screenWidth - 16) {
                                            left =
                                                screenWidth - dialogWidth - 16;
                                          }

                                          double top =
                                              offset.dy - dialogHeight - 16;

                                          return Stack(
                                            children: [
                                              Positioned(
                                                left: left,
                                                top: top,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: BackdropFilter(
                                                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                                      child: Container(
                                                        width: dialogWidth,
                                                        height: dialogHeight,
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.surface.withOpacity(0.8),
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(
                                                            color: Colors.white.withOpacity(0.1),
                                                          ),
                                                        ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16.0,
                                                          ),
                                                      child: Consumer(
                                                        builder: (context, ref, _) {
                                                          final state = ref
                                                              .watch(
                                                                audioProvider,
                                                              );
                                                          return Row(
                                                            children: [
                                                              Icon(
                                                                state.volume ==
                                                                        0
                                                                    ? Icons
                                                                          .volume_off
                                                                    : state.volume <
                                                                          50
                                                                    ? Icons
                                                                          .volume_down
                                                                    : Icons
                                                                          .volume_up,
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                size: 20,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child: SliderTheme(
                                                                  data: SliderTheme.of(context).copyWith(
                                                                    activeTrackColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).primaryColor,
                                                                    inactiveTrackColor: Colors
                                                                        .grey
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                                    thumbColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).primaryColor,
                                                                    thumbShape:
                                                                        const RoundSliderThumbShape(
                                                                          enabledThumbRadius:
                                                                              6,
                                                                        ),
                                                                    trackHeight:
                                                                        4,
                                                                    overlayShape:
                                                                        SliderComponentShape
                                                                            .noOverlay,
                                                                  ),
                                                                  child: Slider(
                                                                    value: state
                                                                        .volume,
                                                                    min: 0.0,
                                                                    max: 100.0,
                                                                    onChanged: (val) => ref
                                                                        .read(
                                                                          audioProvider
                                                                              .notifier,
                                                                        )
                                                                        .setVolume(
                                                                          val,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              SizedBox(
                                                                width: 28,
                                                                child: Text(
                                                                  state.volume
                                                                      .toInt()
                                                                      .toString(),
                                                                  style: TextStyle(
                                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    fontSize: 13,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
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
                                    },
                                  );
                                },
                              ),
                              Consumer(
                                builder: (context, consumerRef, child) {
                                  final isLyricsOpen = consumerRef.watch(
                                    lyricsOverlayProvider,
                                  );
                                  return ModernIconButton(
                                    tooltip: "Lyrics",
                                    icon: Icon(
                                      Icons.lyrics_outlined,
                                      color: isLyricsOpen
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).iconTheme.color?.withOpacity(0.56),
                                    ),
                                    onPressed: () {
                                      consumerRef
                                          .read(lyricsOverlayProvider.notifier)
                                          .toggle();
                                    },
                                  );
                                },
                              ),
                              ModernIconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'Audio Settings',
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (context) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 24.0,
                                          horizontal: 16.0,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Audio Settings',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              'Playback Speed',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                              ),
                                            ),
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final state = ref.watch(
                                                  audioProvider,
                                                );
                                                return Row(
                                                  children: [
                                                    Text(
                                                      '0.5x',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Slider(
                                                        value: state.speed,
                                                        min: 0.5,
                                                        max: 2.0,
                                                        divisions: 15,
                                                        label:
                                                            '${state.speed.toStringAsFixed(1)}x',
                                                        activeColor: Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                        onChanged: (val) => ref
                                                            .read(
                                                              audioProvider
                                                                  .notifier,
                                                            )
                                                            .setSpeed(val),
                                                      ),
                                                    ),
                                                    Text(
                                                      '2.0x',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                              ),
                                            ),
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final state = ref.watch(
                                                  audioProvider,
                                                );
                                                return Row(
                                                  children: [
                                                    Text(
                                                      '-12',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Slider(
                                                        value: state.pitch,
                                                        min: -12.0,
                                                        max: 12.0,
                                                        divisions: 24,
                                                        label: state.pitch
                                                            .toStringAsFixed(1),
                                                        activeColor: Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                        onChanged: (val) => ref
                                                            .read(
                                                              audioProvider
                                                                  .notifier,
                                                            )
                                                            .setPitch(val),
                                                      ),
                                                    ),
                                                    Text(
                                                      '+12',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                                              title: const Text(
                                                'Equalizer Settings',
                                              ),
                                              trailing: Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                              ),
                                              onTap: () {
                                                Navigator.pop(context);
                                                showModalBottomSheet(
                                                  context: context,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  isScrollControlled: true,
                                                  builder: (context) =>
                                                      const EqualizerSheet(),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              ModernIconButton(
                                icon: const Icon(Icons.fullscreen),
                                tooltip: 'Full Screen',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      settings: const RouteSettings(name: '/fullscreen_player'),
                                      pageBuilder: (context, animation, secondaryAnimation) => const FullScreenPlayer(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        var begin = const Offset(0.0, 1.0);
                                        var end = Offset.zero;
                                        var curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
   );
  }

  void _showMediaActions(
    BuildContext context,
    WidgetRef ref,
    MediaItem track,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(
        item: track,
        onDelete: track.id == null
            ? () => _confirmDelete(context, ref, track)
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Permanently delete "${item.title}" from your device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dlg);
              ref.read(libraryProvider.notifier).deleteTrack(item);
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
}
