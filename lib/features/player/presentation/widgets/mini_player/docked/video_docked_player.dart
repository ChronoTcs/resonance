import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import 'package:resonance_app/features/player/presentation/screens/dedicated_video_player.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance_app/features/player/application/providers/video_player_notifier.dart' as v;
import 'package:media_kit_video/media_kit_video.dart' hide VideoState;
import 'package:resonance_app/core/widgets/reusable_seek_slider.dart';
import 'package:resonance_app/features/player/presentation/notifiers/mini_player_view_notifier.dart';
import 'package:resonance_app/core/widgets/play_pause_button.dart';
import 'package:resonance_app/features/player/presentation/widgets/mini_player/shared/volume_popup_dialog.dart';
import 'package:resonance_app/features/player/utils/media_action_utils.dart';

class VideoDockedPlayer extends ConsumerWidget {
  const VideoDockedPlayer({super.key});

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
            : Center(
                child: Icon(UIcons.regular.play_alt, color: Colors.white24, size: 20),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }
    // Membaca state dan notifier di build root
    final videoState = ref.watch(v.videoPlayerProvider);
    
    // Safety check bila kosong maka tidak di-_render_ (ini sudah dicek di parent router, 
    // tetapi kita tambahkan validasi fallback)
    if (videoState.currentVideo == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final videoNotifier = ref.read(v.videoPlayerProvider.notifier);
    final displayTrack = videoState.currentVideo!;

    return GestureDetector(
      onTap: () {
        // SOTA V5.2: Direct Immersion Rule.
        // Tutup PiP (Window) terlebih dahulu agar rute utama tidak Offstage di main.dart
        final isPopped = ref.read(miniPlayerPopProvider).isPopped;
        if (isPopped) {
          ref.read(miniPlayerPopProvider.notifier).togglePop();
        }

        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder(
            settings: const RouteSettings(name: '/fullscreen_player'),
            pageBuilder: (context, animation, secondaryAnimation) => 
                const DedicatedVideoPlayer(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(0, 1), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeInOutCubic),
                  ),
                ),
                child: child,
              );
            },
          ),
        );
      },
      child: SizedBox(
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // SOTA V5.1 Layer 1: Background & Controls (Inside ClipRRect)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    alignment: Alignment.center, // Keeps content vertically balanced
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                      ),
                    ),
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
                           ReusableHoverIconButton(
                            tooltip: 'Jump Back 10s',
                            icon: UIcons.regular.rotate_left,
                            iconSize: 24,
                            onTap: () => videoNotifier.jump(const Duration(seconds: -10)),
                          ),
                          PlayPauseButton(
                            isPlaying: videoState.isPlaying,
                            isLoading: false,
                            size: PlayPauseSize.medium,
                            color: theme.primaryColor,
                            onTap: () => videoNotifier.togglePlayPause(),
                          ),
                          ReusableHoverIconButton(
                            tooltip: 'Jump Forward 10s',
                            icon: UIcons.regular.rotate_right,
                            iconSize: 24,
                            onTap: () => videoNotifier.jump(const Duration(seconds: 10)),
                          ),
                          Builder(
                            builder: (buttonContext) {
                              return ReusableHoverIconButton(
                                tooltip: 'Volume',
                                icon: videoState.volume == 0
                                    ? UIcons.regular.volume_off
                                    : videoState.volume < 0.5
                                        ? UIcons.regular.volume_down
                                        : UIcons.regular.volume,
                                iconSize: 20,
                                onTap: () {
                                  final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
                                  final offset = renderBox.localToGlobal(Offset.zero);
                                  final buttonSize = renderBox.size;
                                  
                                  VolumePopupDialog.show(
                                    context: context,
                                    buttonOffset: offset,
                                    buttonSize: buttonSize,
                                    isVideo: true,
                                  );
                                },
                              );
                            },
                          ),
                          ReusableHoverIconButton(
                            icon: UIcons.regular.add,
                            iconSize: 20,
                            tooltip: 'Media actions',
                            onTap: () => MediaActionUtils.showMediaActions(
                              context: context,
                              ref: ref,
                              item: displayTrack,
                            ),
                          ),
                          ReusableHoverIconButton(
                            icon: UIcons.regular.cross_small,
                            tooltip: 'Close video',
                            iconSize: 20,
                            onTap: () => videoNotifier.closeVideo(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // SOTA V5.1 Layer 2: Floating Seeker (Bebas Melayang di luar 72px boundaries)
            Positioned(
              top: -14, // Sets exactly 16px below and 16px above for maximum hit-area comfort
              left: 0,
              right: 0,
              height: 32,
              child: ReusableSeekSlider(
                value: videoState.position.inMilliseconds.toDouble(),
                max: videoState.duration.inMilliseconds.toDouble() > 0
                    ? videoState.duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (val) {
                  videoNotifier.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
