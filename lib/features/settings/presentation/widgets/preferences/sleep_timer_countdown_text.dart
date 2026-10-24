import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/sleep_timer_provider.dart';

/// Isolated leaf widget that consumes [sleepTimerProvider.remainingDuration].
/// Wrapped in a [RepaintBoundary] to ensure high-frequency (1 Hz) countdown updates
/// only rasterize the text pixels, preventing parent card and page rebuilds.
class SleepTimerCountdownText extends ConsumerWidget {
  final TextStyle? style;
  final bool showRemainingSuffix;

  const SleepTimerCountdownText({
    super.key,
    this.style,
    this.showRemainingSuffix = true,
  });

  /// Formats a [Duration] into compact or verbose human-readable format.
  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      if (seconds > 0) {
        return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
      }
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    if (minutes > 0) {
      if (seconds > 0) {
        return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
      }
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepTimerProvider.select((s) => s.remainingDuration));
    final formatted = formatDuration(remaining);

    return RepaintBoundary(
      child: Text(
        showRemainingSuffix ? '$formatted remaining' : formatted,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

