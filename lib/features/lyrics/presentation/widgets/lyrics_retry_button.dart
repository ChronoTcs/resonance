import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../../application/lyrics_translation_provider.dart';


class LyricsRetryButton extends ConsumerStatefulWidget {
  final String modeLabel;
  const LyricsRetryButton({super.key, required this.modeLabel});

  @override
  ConsumerState<LyricsRetryButton> createState() => _LyricsRetryButtonState();
}

class _LyricsRetryButtonState extends ConsumerState<LyricsRetryButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleRetry() {
    _controller.forward(from: 0);
    ref.read(lyricsTranslationProvider.notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final translationState = ref.watch(lyricsTranslationProvider);
    final isRotating = translationState.isLoading;

    if (isRotating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!isRotating && _controller.isAnimating) {
      _controller.stop();
    }

    return ReusableHoverIconButton(
      tooltip: 'Coba lagi memuat ${widget.modeLabel}',
      onTap: _handleRetry,
      padding: 6,
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          UIcons.regular.refresh,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
