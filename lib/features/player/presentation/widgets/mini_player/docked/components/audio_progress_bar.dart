import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/widgets/inputs/reusable_seek_slider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

/// Progress seek bar anchored at the top edge of [AudioDockedPlayer].
/// Consumes [audioProvider] position and duration, rebuilding only this component on position ticks.
class AudioProgressBar extends ConsumerWidget {
  const AudioProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(audioProvider.select((s) => s.position));
    final dur = ref.watch(audioProvider.select((s) => s.duration));

    return Positioned(
      top: -6.5,
      left: 0,
      right: 0,
      height: 16,
      child: RepaintBoundary(
        child: ReusableSeekSlider(
          value: pos.inMilliseconds.toDouble(),
          max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0,
          height: 16.0,
          trackHeight: 3.0,
          thumbRadius: 5.0,
          onChanged: (_) {},
          onChangeEnd: (val) {
            ref.read(audioProvider.notifier).seek(Duration(milliseconds: val.toInt()));
          },
        ),
      ),
    );
  }
}
