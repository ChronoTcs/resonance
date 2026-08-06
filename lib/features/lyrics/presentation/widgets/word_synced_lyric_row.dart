import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lyric_line.dart';
import '../../application/lyrics_provider.dart';

class WordSyncedLyricRow extends ConsumerWidget {
  final LyricLine line;
  final Duration playerPosition;
  final bool isActive;
  final double activeOpacity;
  final double inactiveOpacity;
  final double fontSizeActive;
  final double fontSizeInactive;

  const WordSyncedLyricRow({
    super.key,
    required this.line,
    required this.playerPosition,
    required this.isActive,
    required this.activeOpacity,
    required this.inactiveOpacity,
    this.fontSizeActive = 26,
    this.fontSizeInactive = 18,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: isActive ? fontSizeActive : fontSizeInactive,
      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
      height: 1.4,
    );

    // Compute offset adjusted position for syllable timing check if offset is adaptive
    final adjustedPosition = ref.watch(adjustedLyricsPositionProvider);
    final syllables = line.syllables;

    // Fallback: If no syllable-level timings exist for this line, render simple Text line
    if (syllables == null || syllables.isEmpty) {
      return Text(
        line.text,
        textAlign: TextAlign.center,
        style: textStyle.copyWith(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isActive ? activeOpacity : inactiveOpacity,
          ),
        ),
      );
    }

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
            final progress = (relativePosition - syllable.offset).inMilliseconds / range;
            opacity = inactiveOpacity + (activeOpacity - inactiveOpacity) * progress.clamp(0.0, 1.0);
          } else {
            opacity = activeOpacity;
          }
        }
      }

      spans.add(
        TextSpan(
          text: '${syllable.text} ',
          style: textStyle.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: opacity),
          ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}
