import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';

import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/full_screen_player/full_screen_audio_view.dart';
import 'package:resonance/features/player/presentation/widgets/full_screen_player/full_screen_bottom_bar.dart';

class FullScreenPlayer extends ConsumerStatefulWidget {
  const FullScreenPlayer({super.key});

  @override
  ConsumerState<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends ConsumerState<FullScreenPlayer> {
  late final FocusNode _focusNode;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleKey);

    // Route is instant. Enter fullscreen immediately, then release the blur.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _enterFullScreen();
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) BlurTransitionOverlay.complete(ref);
    });
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      final showFullLyrics = ref.read(lyricsOverlayProvider);
      if (showFullLyrics) {
        ref.read(lyricsOverlayProvider.notifier).toggle();
      } else {
        _exitWithBlur();
      }
      return true;
    }
    return false;
  }

  /// Exits with blur animation.
  Future<void> _exitWithBlur() async {
    if (!mounted || _isExiting) return;
    setState(() => _isExiting = true);
    
    // 1. Show blur and wait
    await BlurTransitionOverlay.startAndWait(ref);
    // 2. Exit fullscreen
    await _exitFullScreen();
    // 3. Pop route (now allowed since _isExiting is true)
    if (mounted) Navigator.pop(context);
    // 4. Let the default page settle
    await Future.delayed(const Duration(milliseconds: 120));
    // 5. Dismiss blur
    BlurTransitionOverlay.complete(ref);
  }

  Future<void> _enterFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setMinimumSize(const Size(0, 0));
      await windowManager.setMaximumSize(const Size(99999, 99999));
      if (!mounted) return;
      await windowManager.setFullScreen(true);
      _focusNode.requestFocus();
    } else if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _exitFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
    } else if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    final audioState = ref.watch(audioProvider);
    final currentTrack = audioState.currentTrack;
    final showFullLyrics = ref.watch(lyricsOverlayProvider);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: PopScope(
        canPop: _isExiting,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _exitWithBlur();
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final theme = Theme.of(context);
              final isLight = theme.brightness == Brightness.light;

              if (constraints.maxWidth < 400 || constraints.maxHeight < 300) {
                return Container(color: theme.colorScheme.surface);
              }

              return Stack(
                children: [
                  // 1. DYNAMIC BLURRED BACKGROUND
                  Positioned.fill(
                    child: Consumer(
                      builder: (context, ref, _) {
                        if (currentTrack == null) {
                          return Container(color: theme.colorScheme.surface);
                        }
                        return MediaArtworkWidget(
                          item: currentTrack,
                          fit: BoxFit.cover,
                          color: isLight
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.6),
                          colorBlendMode:
                              isLight ? BlendMode.lighten : BlendMode.darken,
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(
                        color: (isLight ? Colors.white : Colors.black)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                  // 2. THE AUDIO VIEW
                  if (currentTrack != null)
                    Positioned.fill(
                      child: !showFullLyrics
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: FullScreenAudioView(displayTrack: currentTrack),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: FullScreenBottomBar(track: currentTrack),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                  // 3. LYRICS OVERLAY
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: showFullLyrics
                          ? Container(
                              key: const ValueKey('lyrics_overlay'),
                              color: theme.colorScheme.surface,
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
      ),
    );
  }
}
