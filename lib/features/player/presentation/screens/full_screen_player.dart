import 'package:resonance/core/widgets/widgets.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:resonance/features/player/presentation/screens/queue_screen.dart';

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
      final showQueue = ref.read(queueOverlayProvider);
      if (showQueue) {
        ref.read(queueOverlayProvider.notifier).setVisible(false);
        return true;
      }
      final showFullLyrics = ref.read(lyricsOverlayProvider);
      if (showFullLyrics) {
        ref.read(lyricsOverlayProvider.notifier).toggle();
        return true;
      }
      _exitWithBlur();
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
      await windowManager.setMinimumSize(const Size(800, 600));
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
    final showQueue = ref.watch(queueOverlayProvider);

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
                  _FullScreenDynamicBackground(
                    currentTrack: currentTrack,
                    isLight: isLight,
                    surfaceColor: theme.colorScheme.surface,
                  ),
                  Positioned.fill(
                    child: _FullScreenAudioStage(
                      currentTrack: currentTrack,
                      showFullLyrics: showFullLyrics,
                      showQueue: showQueue,
                    ),
                  ),
                  _FullScreenLyricsLayer(
                    showFullLyrics: showFullLyrics,
                    surfaceColor: theme.colorScheme.surface,
                  ),
                  _FullScreenQueueLayer(
                    showQueue: showQueue,
                    surfaceColor: theme.colorScheme.surface,
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

class _FullScreenDynamicBackground extends StatelessWidget {
  final dynamic currentTrack;
  final bool isLight;
  final Color surfaceColor;

  const _FullScreenDynamicBackground({
    required this.currentTrack,
    required this.isLight,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: currentTrack == null
              ? Container(color: surfaceColor)
              : MediaArtworkWidget(
                  item: currentTrack,
                  fit: BoxFit.cover,
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                  colorBlendMode: isLight ? BlendMode.lighten : BlendMode.darken,
                ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              color: (isLight ? Colors.white : Colors.black).withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenAudioStage extends StatelessWidget {
  final dynamic currentTrack;
  final bool showFullLyrics;
  final bool showQueue;

  const _FullScreenAudioStage({
    required this.currentTrack,
    required this.showFullLyrics,
    required this.showQueue,
  });

  @override
  Widget build(BuildContext context) {
    if (currentTrack == null || showFullLyrics || showQueue) {
      return const SizedBox.shrink();
    }

    return Stack(
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
    );
  }
}

class _FullScreenLyricsLayer extends StatelessWidget {
  final bool showFullLyrics;
  final Color surfaceColor;

  const _FullScreenLyricsLayer({
    required this.showFullLyrics,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: showFullLyrics
            ? Container(
                key: const ValueKey('lyrics_overlay'),
                color: surfaceColor,
                child: const LyricsScreen(isEmbedded: true),
              )
            : const SizedBox.shrink(key: ValueKey('lyrics_empty')),
      ),
    );
  }
}

class _FullScreenQueueLayer extends StatelessWidget {
  final bool showQueue;
  final Color surfaceColor;

  const _FullScreenQueueLayer({
    required this.showQueue,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: showQueue
            ? Container(
                key: const ValueKey('queue_overlay'),
                color: surfaceColor,
                child: const QueueScreen(isEmbedded: true),
              )
            : const SizedBox.shrink(key: ValueKey('queue_empty')),
      ),
    );
  }
}
