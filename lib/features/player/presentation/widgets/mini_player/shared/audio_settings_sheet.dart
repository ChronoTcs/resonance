import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/equalizer_sheet.dart';

class AudioSettingsSheet extends ConsumerWidget {
  const AudioSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => const AudioSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 24.0,
        horizontal: 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Audio Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Playback Speed',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(audioProvider);
              return Row(
                children: [
                  Text(
                    '0.5x',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: state.speed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: '${state.speed.toStringAsFixed(1)}x',
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) => ref
                          .read(audioProvider.notifier)
                          .setSpeed(val),
                    ),
                  ),
                  Text(
                    '2.0x',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Pitch',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(audioProvider);
              return Row(
                children: [
                  Text(
                    '-12',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: state.pitch,
                      min: -12.0,
                      max: 12.0,
                      divisions: 24,
                      label: state.pitch.toStringAsFixed(1),
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) => ref
                          .read(audioProvider.notifier)
                          .setPitch(val),
                    ),
                  ),
                  Text(
                    '+12',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(
              UIcons.regular.settings_sliders,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: const Text('Equalizer Settings'),
            trailing: Icon(
              UIcons.regular.angle_small_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const EqualizerSheet(),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
