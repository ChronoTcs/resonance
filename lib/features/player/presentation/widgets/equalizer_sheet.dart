import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/equalizer_controller.dart';

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

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
    final eqState = ref.watch(equalizerControllerProvider);
    final eqNotifier = ref.read(equalizerControllerProvider.notifier);

    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    return Container(
      height: 480,
      padding: const EdgeInsets.only(
        top: 24.0,
        left: 32.0,
        right: 32.0,
        bottom: 16.0,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: [
                  Text(
                    eqState.isEnabled ? 'On' : 'Off',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: eqState.isEnabled,
                    onChanged: (val) {
                      eqNotifier.toggleEqualizer(val);
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
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 16),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: eqState.preset,
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: onSurfaceVariant,
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
                            color: eqState.preset == value
                                ? colorScheme.primary
                                : onSurface,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null && newValue != 'Custom') {
                        eqNotifier.setEqualizerPreset(newValue);
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
                  children: [
                    Text(
                      '+12 dB',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    Text(
                      ' +6 dB',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    Text(
                      '  0 dB',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    Text(
                      ' -6 dB',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    Text(
                      '-12 dB',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 20), // Spacer for bottom labels alignment
                  ],
                ),
                const SizedBox(width: 16),

                // Sliders
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(9, (index) {
                        return SizedBox(
                          width: 56, // Fixed width for each band to ensure scrollability
                          child: Column(
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
                                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    // Slider
                                    RotatedBox(
                                      quarterTurns: 3,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4,
                                          activeTrackColor: colorScheme.primary,
                                          inactiveTrackColor: colorScheme.surfaceContainerHighest,
                                          thumbColor: colorScheme.primary,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 9,
                                            elevation: 2,
                                          ),
                                          overlayShape:
                                              SliderComponentShape.noOverlay,
                                        ),
                                        child: Slider(
                                          value: eqState.bands[index],
                                          min: -12.0,
                                          max: 12.0,
                                          onChanged: eqState.isEnabled
                                              ? (val) {
                                                  eqNotifier.setEqualizerBand(
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Control Row
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Checkbox
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: eqState.linkSliders,
                        activeColor: colorScheme.primary,
                        checkColor: colorScheme.onPrimary,
                        side: BorderSide(color: onSurfaceVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          if (val != null) eqNotifier.toggleLinkSliders(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Move nearby sliders together',
                        style: TextStyle(color: onSurfaceVariant, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
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
