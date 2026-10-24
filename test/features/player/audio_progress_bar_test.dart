import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/widgets/inputs/reusable_seek_slider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_progress_bar.dart';

class _FakeAudioNotifier extends AudioNotifier {
  final AudioState _initial;
  _FakeAudioNotifier(this._initial);

  @override
  AudioState build() => _initial;

  @override
  void seek(Duration position) {
    state = state.copyWith(position: position);
  }
}

void main() {
  group('AudioProgressBar Widget Tests', () {
    testWidgets('renders ReusableSeekSlider inside Stack with position & duration', (tester) async {
      final notifier = _FakeAudioNotifier(
        AudioState(
          position: const Duration(seconds: 30),
          duration: const Duration(seconds: 120),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  AudioProgressBar(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AudioProgressBar), findsOneWidget);
      final sliderFinder = find.byType(ReusableSeekSlider);
      expect(sliderFinder, findsOneWidget);

      final slider = tester.widget<ReusableSeekSlider>(sliderFinder);
      expect(slider.value, equals(30000.0));
      expect(slider.max, equals(120000.0));
      expect(slider.height, equals(16.0));
      expect(slider.trackHeight, equals(3.0));
    });
  });
}
