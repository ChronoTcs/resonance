import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';

import '../../../player/application/providers/audio_provider.dart';

class AudioSettingsSection extends ConsumerWidget {
  const AudioSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Playback & Audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            ResonanceButton(
              onPressed: () {
                audioNotifier.restoreToDefault();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio settings restored to default.')),
                );
              },
              icon: UIcons.regular.undo_alt,
              label: 'Reset to Defaults',
              style: ResonanceButtonStyle.secondary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Volume
        ResonanceSlider(
          title: 'Volume (${audioState.volume.toInt()}%)',
          value: audioState.volume,
          min: 0,
          max: 100,
          iconLeft: UIcons.regular.volume_mute,
          iconRight: UIcons.regular.volume,
          onChanged: (val) => audioNotifier.setVolume(val),
        ),
        
        const SizedBox(height: 12),
        
        // Speed
        ResonanceSlider(
          title: 'Playback Speed (${audioState.speed.toStringAsFixed(1)}x)',
          value: audioState.speed,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          labelLeft: '0.5x',
          labelRight: '2.0x',
          onChanged: (val) => audioNotifier.setSpeed(val),
        ),
        
        const SizedBox(height: 12),
        
        // Pitch
        ResonanceSlider(
          title: 'Pitch (${audioState.pitch > 0 ? '+' : ''}${audioState.pitch.toStringAsFixed(1)})',
          value: audioState.pitch,
          min: -12.0,
          max: 12.0,
          divisions: 24,
          labelLeft: '-12',
          labelRight: '+12',
          onChanged: (val) => audioNotifier.setPitch(val),
        ),
      ],
    );
  }
}
