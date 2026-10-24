import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/shared/audio_settings_sheet.dart';

class _TestAudioNotifier extends AudioNotifier {
  double currentVol = 75.0;

  @override
  AudioState build() => AudioState(volume: currentVol, speed: 1.0, pitch: 0.0);

  @override
  void setVolume(double v) {
    currentVol = v;
    state = state.copyWith(volume: v);
  }

  @override
  void setSpeed(double s) {
    state = state.copyWith(speed: s);
  }

  @override
  void setPitch(double p) {
    state = state.copyWith(pitch: p);
  }
}

void main() {
  group('AudioSettingsSheet Widget Tests', () {
    testWidgets('renders Volume slider with percentage and controls volume', (tester) async {
      final notifier = _TestAudioNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AudioSettingsSheet(),
            ),
          ),
        ),
      );

      // Verify title & sections
      expect(find.text('Audio Settings'), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Playback Speed'), findsOneWidget);
      expect(find.text('Pitch'), findsOneWidget);
      expect(find.text('Equalizer Settings'), findsOneWidget);

      // Verify continuous slider (zero divisions tick marks)
      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(3)); // Volume, Speed, Pitch

      final volumeSlider = tester.widget<Slider>(sliders.first);
      expect(volumeSlider.divisions, isNull);
      expect(volumeSlider.min, 0.0);
      expect(volumeSlider.max, 100.0);
      expect(volumeSlider.value, 75.0);

      // Tap speaker icon / Volume label to mute
      await tester.tap(find.text('Volume'));
      await tester.pumpAndSettle();

      expect(notifier.currentVol, equals(0.0));
      expect(find.text('0%'), findsWidgets);

      // Tap again to unmute
      await tester.tap(find.text('Volume'));
      await tester.pumpAndSettle();

      expect(notifier.currentVol, equals(75.0));
      expect(find.text('75%'), findsOneWidget);
    });
  });
}

