import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import '../../../player/application/providers/audio_provider.dart';

/// Compact ±0.5s lyrics offset adjustment control.
/// Reads lyricsOffset from audioProvider and calls adjustLyricsOffset.
/// Offset is automatically reset to zero on every track change (handled in _onTrackChanged).
class LyricsOffsetControl extends ConsumerWidget {
  /// Visual scale: use [compact] for tight spaces like the mini lyrics card header.
  final bool compact;
  const LyricsOffsetControl({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offsetMs = ref.watch(
      audioProvider.select((s) => s.currentTrack?.lyricsOffset.inMilliseconds ?? 0),
    );
    final notifier = ref.read(audioProvider.notifier);
    final iconSize = compact ? 15.0 : 18.0;
    final fontSize = compact ? 11.0 : 12.0;
    final color = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReusableHoverIconButton(
          icon: UIcons.regular.minus,
          iconSize: iconSize,
          padding: compact ? 2.0 : 3.0,
          borderRadius: BorderRadius.circular(4),
          color: color.withValues(alpha: 0.85),
          tooltip: 'Delay lyrics 0.5s',
          onTap: () => notifier.adjustLyricsOffset(const Duration(milliseconds: -500)),
        ),
        const SizedBox(width: 3),
        Text(
          '${(offsetMs / 1000).toStringAsFixed(1)}s',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 3),
        ReusableHoverIconButton(
          icon: UIcons.regular.plus,
          iconSize: iconSize,
          padding: compact ? 2.0 : 3.0,
          borderRadius: BorderRadius.circular(4),
          color: color.withValues(alpha: 0.85),
          tooltip: 'Advance lyrics 0.5s',
          onTap: () => notifier.adjustLyricsOffset(const Duration(milliseconds: 500)),
        ),
      ],
    );
  }
}
