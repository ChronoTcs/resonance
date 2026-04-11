import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
import '../../../../core/data/services/storage_service.dart';
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
        const Text(
          'Audio Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        
        // Volume
        _buildAudioSlider(
          context,
          title: 'Volume (${audioState.volume.toInt()}%)',
          value: audioState.volume,
          min: 0,
          max: 100,
          iconLeft: Icons.volume_mute,
          iconRight: Icons.volume_up,
          onChanged: (val) => audioNotifier.setVolume(val),
        ),
        
        const SizedBox(height: 12),
        
        // Speed
        _buildAudioSlider(
          context,
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
        _buildAudioSlider(
          context,
          title: 'Pitch (${audioState.pitch > 0 ? '+' : ''}${audioState.pitch.toStringAsFixed(1)})',
          value: audioState.pitch,
          min: -12.0,
          max: 12.0,
          divisions: 24,
          labelLeft: '-12',
          labelRight: '+12',
          onChanged: (val) => audioNotifier.setPitch(val),
        ),
        
        const SizedBox(height: 24),
        
        // [V20.5 SOTA] YouTube Playback Engine selection
        _buildEngineSelector(context, ref),
        
        const SizedBox(height: 24),
        
        Center(
          child: ReusableHoverIconButton(
            tooltip: 'Reset to default playback settings',
            onTap: () {
              audioNotifier.restoreToDefault();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio settings restored to default.')),
              );
            },
            padding: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.restore),
                SizedBox(width: 8),
                Text('Restore Audio Defaults'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEngineSelector(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(sharedPreferencesProvider);
    final currentEngine = prefs.getString('yt_engine') ?? 'innertube';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YouTube Playback Engine', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: currentEngine == 'explode' ? 'explode' : 'innertube',
            isExpanded: true,
            dropdownColor: theme.colorScheme.surface,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'innertube',
                child: Text('InnerTube (Recommended - High Speed)'),
              ),
              DropdownMenuItem(
                value: 'explode',
                child: Text('youtube_explode (Alternative - Stable)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                prefs.setString('yt_engine', val);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Engine changed to $val. Restart playback to apply.')),
                );
              }
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'InnerTube uses pure JSON (zero latency). Pick youtube_explode if you experience playback issues.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSlider(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    int? divisions,
    IconData? iconLeft,
    IconData? iconRight,
    String? labelLeft,
    String? labelRight,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Row(
            children: [
              if (iconLeft != null) Icon(iconLeft, size: 20, color: Colors.grey),
              if (labelLeft != null) Text(labelLeft, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  activeColor: theme.primaryColor,
                  onChanged: onChanged,
                ),
              ),
              if (iconRight != null) Icon(iconRight, size: 20, color: Colors.grey),
              if (labelRight != null) Text(labelRight, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
