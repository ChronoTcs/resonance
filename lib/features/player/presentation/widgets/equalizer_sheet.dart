import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/audio_provider.dart';

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({Key? key}) : super(key: key);

  static const List<String> _bandLabels = [
    '62 Hz',
    '125 Hz',
    '250 Hz',
    '500 Hz',
    '1 kHz',
    '2 kHz',
    '4 kHz',
    '8 kHz',
    '16 kHz',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    // Background colors matching the screenshot
    const bgColor = Color(0xFF2B2B2B);
    const surfaceColor = Color(0xFF3B3B3B);
    const accentColor = Colors.white;
    const mutedColor = Color(0xFFAAAAAA);

    return Container(
      height: 480,
      padding: const EdgeInsets.only(
        top: 24.0,
        left: 32.0,
        right: 32.0,
        bottom: 16.0,
      ),
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Equaliser',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  Text(
                    audioState.isEqualizerEnabled ? 'On' : 'Off',
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: audioState.isEqualizerEnabled,
                    activeColor: Colors.black,
                    activeTrackColor: Colors.white,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                    onChanged: (val) {
                      audioNotifier.toggleEqualizer(val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Preset Row
          Row(
            children: [
              const Text(
                'Preset',
                style: TextStyle(color: accentColor, fontSize: 16),
              ),
              const SizedBox(width: 16),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: audioState.equalizerPreset,
                    dropdownColor: surfaceColor,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: mutedColor,
                      size: 20,
                    ),
                    items: ['Flat', 'Bass Boost', 'Vocal', 'Custom'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: audioState.equalizerPreset == value
                                ? accentColor
                                : mutedColor,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null && newValue != 'Custom') {
                        audioNotifier.setEqualizerPreset(newValue);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Sliders Area
          Expanded(
            child: Row(
              children: [
                // Y-Axis Labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '+12 dB',
                      style: TextStyle(color: accentColor, fontSize: 12),
                    ),
                    Text(
                      ' +6 dB',
                      style: TextStyle(color: accentColor, fontSize: 12),
                    ),
                    Text(
                      '  0 dB',
                      style: TextStyle(color: accentColor, fontSize: 12),
                    ),
                    Text(
                      ' -6 dB',
                      style: TextStyle(color: accentColor, fontSize: 12),
                    ),
                    Text(
                      '-12 dB',
                      style: TextStyle(color: accentColor, fontSize: 12),
                    ),
                    SizedBox(height: 20), // Spacer for bottom labels alignment
                  ],
                ),
                const SizedBox(width: 16),

                // Sliders
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(9, (index) {
                      return Column(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background Tick marks
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    5,
                                    (_) => Container(
                                      width: 24,
                                      height: 1,
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                                // Slider
                                RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      activeTrackColor: mutedColor,
                                      inactiveTrackColor: mutedColor,
                                      thumbColor: const Color(0xFF555555),
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 9,
                                        elevation: 0,
                                      ),
                                      overlayShape:
                                          SliderComponentShape.noOverlay,
                                    ),
                                    child: Slider(
                                      value: audioState.equalizerBands[index],
                                      min: -12.0,
                                      max: 12.0,
                                      onChanged: audioState.isEqualizerEnabled
                                          ? (val) {
                                              audioNotifier.setEqualizerBand(
                                                index,
                                                val,
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _bandLabels[index],
                            style: const TextStyle(
                              fontSize: 12,
                              color: accentColor,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Control Row
          const Divider(color: surfaceColor, thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Checkbox
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: audioState.linkEqualizerSliders,
                      activeColor: surfaceColor,
                      checkColor: mutedColor,
                      side: const BorderSide(color: mutedColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        if (val != null) audioNotifier.toggleLinkSliders(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Move nearby sliders together',
                    style: TextStyle(color: mutedColor, fontSize: 14),
                  ),
                ],
              ),
              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: surfaceColor,
                  foregroundColor: accentColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
