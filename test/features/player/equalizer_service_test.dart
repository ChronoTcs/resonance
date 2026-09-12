import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/player/application/services/equalizer_service.dart';

void main() {
  group('EqualizerService', () {
    const service = EqualizerService();

    test('All presets have exactly 9 bands bounded within [-12.0, 12.0] dB', () {
      expect(kEqualizerPresets.length, greaterThanOrEqualTo(22));

      for (final entry in kEqualizerPresets.entries) {
        final name = entry.key;
        final bands = entry.value;

        expect(bands.length, equals(9), reason: 'Preset "$name" must have 9 bands');
        for (int i = 0; i < bands.length; i++) {
          expect(
            bands[i],
            inInclusiveRange(-12.0, 12.0),
            reason: 'Band $i of preset "$name" out of bounds',
          );
        }
      }
    });

    test('getPresetBands returns copy of preset bands and falls back to Flat', () {
      final rockBands = service.getPresetBands('Rock');
      expect(rockBands, equals(kEqualizerPresets['Rock']));

      // Modifying returned list does not mutate constant map
      rockBands[0] = 99.0;
      expect(service.getPresetBands('Rock')[0], isNot(99.0));

      // Unknown preset falls back to Flat
      final unknown = service.getPresetBands('NonExistentPreset123');
      expect(unknown, equals(kEqualizerPresets['Flat']));
    });

    test('All categories in kEqualizerPresetCategories contain valid presets', () {
      expect(kEqualizerPresetCategories.isNotEmpty, isTrue);

      for (final entry in kEqualizerPresetCategories.entries) {
        expect(entry.value.isNotEmpty, isTrue);
        for (final preset in entry.value) {
          expect(
            kEqualizerPresets.containsKey(preset),
            isTrue,
            reason: 'Category "${entry.key}" references undefined preset "$preset"',
          );
        }
      }
    });

    test('generateFilterString creates valid FFmpeg equalizer filter chain when enabled', () {
      final bands = [6.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -3.0];
      final filter = service.generateFilterString(bands, enabled: true);

      expect(filter, contains('equalizer=f=62.5:width_type=o:w=1:g=6.0'));
      expect(filter, contains('equalizer=f=16000.0:width_type=o:w=1:g=-3.0'));
      // Zero bands are omitted for efficiency
      expect(filter, isNot(contains('equalizer=f=125.0')));

      // When disabled, returns empty string
      final disabledFilter = service.generateFilterString(bands, enabled: false);
      expect(disabledFilter, isEmpty);
    });

    test('calculateLinkedBands applies 50% delta to 1st neighbors and 25% to 2nd neighbors', () {
      final initial = List.filled(9, 0.0);
      final linked = service.calculateLinkedBands(
        index: 4, // 1 kHz band (center)
        newValue: 4.0,
        currentBands: initial,
      );

      expect(linked[4], equals(4.0)); // Center moved +4.0
      expect(linked[3], equals(2.0)); // 1st neighbor left: 50% of 4.0 = +2.0
      expect(linked[5], equals(2.0)); // 1st neighbor right: 50% of 4.0 = +2.0
      expect(linked[2], equals(1.0)); // 2nd neighbor left: 25% of 4.0 = +1.0
      expect(linked[6], equals(1.0)); // 2nd neighbor right: 25% of 4.0 = +1.0
      expect(linked[0], equals(0.0)); // Further bands unaffected
      expect(linked[8], equals(0.0));
    });
  });
}
