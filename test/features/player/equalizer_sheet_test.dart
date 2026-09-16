import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/player/presentation/widgets/equalizer/equalizer_band_slider.dart';
import 'package:resonance/features/player/presentation/widgets/equalizer/equalizer_curve_visualizer.dart';
import 'package:resonance/features/player/presentation/widgets/equalizer/equalizer_preset_selector.dart';

void main() {
  group('Equalizer UI Components', () {
    testWidgets('EqualizerCurveVisualizer paints smoothly with given bands', (tester) async {
      final bands = [6.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: EqualizerCurveVisualizer(
              bands: bands,
              isEnabled: true,
              height: 90.0,
            ),
          ),
        ),
      );

      expect(find.byType(EqualizerCurveVisualizer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify animation pump
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('EqualizerPresetSelector renders chips and handles selection', (tester) async {
      String selectedPreset = 'Flat';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: EqualizerPresetSelector(
              activePreset: selectedPreset,
              onPresetSelected: (p) => selectedPreset = p,
            ),
          ),
        ),
      );

      // Verify "All (22)" button exists
      expect(find.textContaining('All ('), findsOneWidget);

      // Verify popular preset chips exist
      expect(find.text('Flat'), findsOneWidget);
      expect(find.text('Bass Boost'), findsOneWidget);

      // Tap 'Bass Boost' chip
      await tester.tap(find.text('Bass Boost'));
      await tester.pumpAndSettle();

      expect(selectedPreset, equals('Bass Boost'));
    });

    testWidgets('EqualizerBandSlider formats dB correctly and adapts to non-zero values', (tester) async {
      double sliderVal = 3.5;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 50,
              height: 200,
              child: EqualizerBandSlider(
                label: '1 kHz',
                value: sliderVal,
                isEnabled: true,
                onChanged: (val) => sliderVal = val,
              ),
            ),
          ),
        ),
      );

      // Verify dB readout
      expect(find.text('+3.5 dB'), findsOneWidget);
      expect(find.text('1 kHz'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('EqualizerBandsConsole adapts to mobile screen width (<44dp per band)', (tester) async {
      final labels = ['62 Hz', '125 Hz', '250 Hz', '500 Hz', '1 kHz', '2 kHz', '4 kHz', '8 kHz', '16 kHz'];
      final bands = List.filled(9, 0.0);

      // Constrain width to 320dp (narrow Android mobile)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: EqualizerBandsConsole(
                  labels: labels,
                  bands: bands,
                  isEnabled: true,
                  onBandChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );

      // In narrow screen mode (<44dp per band), it enables horizontal SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(EqualizerBandSlider), findsWidgets);
    });

    testWidgets('EqualizerBandsConsole expands across width on desktop/tablet (>=44dp per band)', (tester) async {
      final labels = ['62 Hz', '125 Hz', '250 Hz', '500 Hz', '1 kHz', '2 kHz', '4 kHz', '8 kHz', '16 kHz'];
      final bands = List.filled(9, 0.0);

      // Width 540dp (Desktop / Tablet floating sheet)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 540,
                child: EqualizerBandsConsole(
                  labels: labels,
                  bands: bands,
                  isEnabled: true,
                  onBandChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );

      // On wide screens, fits all 9 bands with Expanded inside Row without horizontal scroll
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(EqualizerBandSlider), findsNWidgets(9));
    });
  });
}
