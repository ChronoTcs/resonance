import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/theme/app_theme.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/sleep_timer_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/shared/sleep_timer_quick_sheet.dart';
import 'package:resonance/features/settings/presentation/widgets/preferences/custom_sleep_timer_sheet.dart';

class _MockAudioNotifier extends AudioNotifier {
  final MediaItem? current;
  _MockAudioNotifier({this.current});

  @override
  AudioState build() => AudioState(currentTrack: current);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
    ProviderContainer? container,
    MediaItem? currentTrack,
  }) {
    return UncontrolledProviderScope(
      container: container ??
          ProviderContainer(
            overrides: [
              audioProvider.overrideWith(() => _MockAudioNotifier(current: currentTrack)),
            ],
          ),
      child: MaterialApp(
        theme: AppTheme.getLightTheme(null),
        home: Scaffold(body: child),
      ),
    );
  }

  group('SleepTimerQuickSheet Widget Tests', () {
    testWidgets('Renders all standard presets and Custom option', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(child: const SleepTimerQuickSheet()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.text('15 Minutes'), findsOneWidget);
      expect(find.text('30 Minutes'), findsOneWidget);
      expect(find.text('45 Minutes'), findsOneWidget);
      expect(find.text('60 Minutes (1 Hour)'), findsOneWidget);
      expect(find.text('End of Current Track'), findsOneWidget);
      expect(find.text('Custom Time...'), findsOneWidget);
    });

    testWidgets('Tapping 15 Minutes preset activates timer', (tester) async {
      final container = ProviderContainer(
        overrides: [
          audioProvider.overrideWith(() => _MockAudioNotifier()),
        ],
      );
      addTearDown(() {
        container.read(sleepTimerProvider.notifier).deactivate();
        container.dispose();
      });

      await tester.pumpWidget(
        buildTestWidget(
          container: container,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => SleepTimerQuickSheet.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open quick sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap 15 Minutes preset
      await tester.tap(find.text('15 Minutes'));
      await tester.pumpAndSettle();

      // Verify timer is armed with 15 minutes
      final state = container.read(sleepTimerProvider);
      expect(state.isEnabled, isTrue);
      container.read(sleepTimerProvider.notifier).deactivate();
      expect(state.selectedMode, equals(SleepTimerMode.duration));
      expect(state.selectedDuration, equals(const Duration(minutes: 15)));
      expect(state.remainingDuration.inMinutes, equals(15));
      container.read(sleepTimerProvider.notifier).deactivate();
    });

    testWidgets('Active timer displays banner with Turn Off and +5 Min buttons', (tester) async {
      final container = ProviderContainer(
        overrides: [
          audioProvider.overrideWith(() => _MockAudioNotifier()),
        ],
      );
      addTearDown(() {
        container.read(sleepTimerProvider.notifier).deactivate();
        container.dispose();
      });

      // Pre-arm 30m timer
      container.read(sleepTimerProvider.notifier).setDuration(const Duration(minutes: 30));

      await tester.pumpWidget(
        buildTestWidget(
          container: container,
          child: const SleepTimerQuickSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Active banner elements
      expect(find.text('Active: '), findsOneWidget);
      expect(find.text('+5 Min'), findsOneWidget);
      expect(find.text('Turn Off'), findsOneWidget);

      // Tap +5 Min
      await tester.tap(find.text('+5 Min'));
      await tester.pump();
      expect(container.read(sleepTimerProvider).remainingDuration.inMinutes, equals(35));

      // Tap Turn Off
      await tester.tap(find.text('Turn Off'));
      await tester.pumpAndSettle();
      expect(container.read(sleepTimerProvider).isEnabled, isFalse);
    });

    testWidgets('Opening Custom Timer and saving does not throw unmounted ref StateError', (tester) async {
      final container = ProviderContainer(
        overrides: [
          audioProvider.overrideWith(() => _MockAudioNotifier()),
        ],
      );
      addTearDown(() {
        container.read(sleepTimerProvider.notifier).deactivate();
        container.dispose();
      });

      await tester.pumpWidget(
        buildTestWidget(
          container: container,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => SleepTimerQuickSheet.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open quick sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Custom Time...
      await tester.tap(find.text('Custom Time...'));
      await tester.pumpAndSettle();

      // Custom sheet should be visible and quick sheet unmounted
      expect(find.byType(CustomSleepTimerSheet), findsOneWidget);

      // Tap Set Timer button
      await tester.tap(find.text('Set Timer'));
      await tester.pumpAndSettle();

      // Verify no StateError thrown and timer is armed
      expect(tester.takeException(), isNull);
      final state = container.read(sleepTimerProvider);
      expect(state.isEnabled, isTrue);
      container.read(sleepTimerProvider.notifier).deactivate();
    });
  });
}

