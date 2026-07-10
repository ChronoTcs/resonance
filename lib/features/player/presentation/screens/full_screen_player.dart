import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/video_player_notifier.dart';
import 'package:resonance/features/player/presentation/widgets/full_screen_player/full_screen_audio_view.dart';
import 'package:resonance/features/player/presentation/widgets/full_screen_player/full_screen_video_view.dart';
import 'package:resonance/features/player/presentation/widgets/full_screen_player/full_screen_bottom_bar.dart';

/// [FullScreenPlayer] — Pure Orchestrator (SOTA V13.21)
///
/// Tanggung jawab tunggal:
/// 1. Manajemen siklus hidup jendela fullscreen (Enter/Exit via windowManager).
/// 2. Memilih dan menampilkan satu dari dua mode: Audio atau Video.
/// 3. Menampilkan Lyrics Overlay di atas semua layer.
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

    // SOTA V5.2: Anti-Delay Rule. Trigger Fullscreen ONLY after route transition is finished.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          _enterFullScreen();
        } else {
          void listener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              _enterFullScreen();
              route.animation!.removeStatusListener(listener);
            }
          }
          route.animation!.addStatusListener(listener);
        }
      } else {
        _enterFullScreen();
      }
    });
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      final showFullLyrics = ref.read(lyricsOverlayProvider);
      if (showFullLyrics) {
        ref.read(lyricsOverlayProvider.notifier).toggle();
      } else {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
      return true;
    }
    return false;
  }

  Future<void> _enterFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // SOTA V9.0: Zero Gravity Protocol.
      await windowManager.setMinimumSize(const Size(0, 0));
      await windowManager.setMaximumSize(const Size(99999, 99999));
      await windowManager.setAlwaysOnTop(false);
      // SOTA V5.2: Deterministic Order (TitleBar Style MUST be first)
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
      if (!mounted) return;
      await windowManager.setFullScreen(true);
      _focusNode.requestFocus();
    }
  }

  Future<void> _exitFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
      Future.microtask(() async {
        if (!mounted) return;
        await windowManager.setTitleBarStyle(
          TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _focusNode.dispose();
    _exitFullScreen();
    super.dispose();
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

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // SOTA V10.0: The Blackout Shield
            if (constraints.maxWidth < 400 || constraints.maxHeight < 300) {
              return Container(color: Colors.black);
            }

            return Stack(
              children: [
                // 1. DYNAMIC BLURRED BACKGROUND (Shared for all modes)
                Positioned.fill(
                  child: Consumer(
                    builder: (context, ref, _) {
                      if (displayTrack == null) return Container(color: Colors.black);
                      return MediaArtworkWidget(
                        item: displayTrack,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.6),
                        colorBlendMode: BlendMode.darken,
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                    child: Container(color: Colors.black.withValues(alpha: 0.4)),
                  ),
                ),

                // 2. THE GREAT BIFURCATION (SOTA V8.0)
                //    Pilih tampilan berdasarkan mode: Video atau Audio.
                if (isVideo)
                  // --- MODE A: IMMERSIVE VIDEO ---
                  Positioned.fill(
                    child: Stack(
                      children: [
                        const Positioned.fill(child: FullScreenVideoView()),
                        if (!showFullLyrics)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: FullScreenBottomBar(track: displayTrack),
                          ),
                      ],
                    ),
                  )
                else if (displayTrack != null)
                  // --- MODE B: DYNAMIC SCROLL AUDIO ---
                  Positioned.fill(
                    child: !showFullLyrics
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: FullScreenAudioView(displayTrack: displayTrack),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: FullScreenBottomBar(track: displayTrack),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                // 3. LYRICS OVERLAY (Global – muncul di atas semua mode)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: showFullLyrics
                        ? Container(
                            key: const ValueKey('lyrics_overlay'),
                            color: Colors.black,
                            child: const LyricsScreen(isEmbedded: true),
                          )
                        : const SizedBox.shrink(key: ValueKey('lyrics_empty')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
