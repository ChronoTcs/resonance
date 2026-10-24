import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lyric_line.dart';
import '../../application/lyrics_provider.dart';
import '../../../../core/application/providers/window_lifecycle_provider.dart';

class WordSyncedLyricRow extends ConsumerWidget {
  final LyricLine line;
  final Duration playerPosition;
  final bool isActive;
  final double activeOpacity;
  final double inactiveOpacity;
  final double fontSizeActive;
  final double fontSizeInactive;
  final Color? textColor;

  const WordSyncedLyricRow({
    super.key,
    required this.line,
    required this.playerPosition,
    required this.isActive,
    required this.activeOpacity,
    required this.inactiveOpacity,
    this.fontSizeActive = 26,
    this.fontSizeInactive = 18,
    this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onSurface;

    final targetStyle = TextStyle(
      fontSize: isActive ? fontSizeActive : fontSizeInactive,
      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
      height: 1.4,
      color: effectiveTextColor.withValues(
        alpha: isActive ? activeOpacity : inactiveOpacity,
      ),
    );

    final syllables = line.syllables;
    final isRenderActive = ref.watch(isWindowRenderActiveProvider);

    // Inactive rows, hidden windows, or lines without syllable timings render animated text style
    // without subscribing to per-tick position stream updates
    if (!isRenderActive || !isActive || syllables == null || syllables.isEmpty) {
      return AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        textAlign: TextAlign.center,
        style: targetStyle,
        child: Text(
          line.text,
          textAlign: TextAlign.center,
        ),
      );
    }

    // Only active word-synced rows subscribe to per-tick position updates
    final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);

    // Syllable/word-by-word animation processing
    final List<InlineSpan> spans = [];
    final relativePosition = adjustedPosition - line.timestamp;

    for (final syllable in syllables) {
      double opacity = inactiveOpacity;

      if (isActive) {
        if (relativePosition >= syllable.offset + syllable.duration) {
          // Word is completely sung: full highlight opacity
          opacity = activeOpacity;
        } else if (relativePosition >= syllable.offset) {
          // Word is currently being sung: interpolate opacity between inactive and active
          final range = syllable.duration.inMilliseconds;
          if (range > 0) {
            final progress =
                (relativePosition - syllable.offset).inMilliseconds / range;
            opacity = inactiveOpacity +
                (activeOpacity - inactiveOpacity) * progress.clamp(0.0, 1.0);
          } else {
            opacity = activeOpacity;
          }
        }
      }

      spans.add(
        TextSpan(
          text: '${syllable.text} ',
          style: TextStyle(
            color: effectiveTextColor.withValues(alpha: opacity),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        textAlign: TextAlign.center,
        style: targetStyle,
        child: Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
