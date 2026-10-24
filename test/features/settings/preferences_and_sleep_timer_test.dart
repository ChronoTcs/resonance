import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/theme/app_theme.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/sleep_timer_provider.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance/features/settings/presentation/widgets/preferences_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAudioNotifier extends AudioNotifier {
  @override
  AudioState build() => AudioState();
}

void main() {
  group('SleepTimerState & SleepTimerNotifier Tests', () {
    test('Initial state is idle (none, disabled) with default 30m preset', () {
      final state = const SleepTimerState();
      expect(state.isActive, isFalse);
      expect(state.isEnabled, isFalse);
      expect(state.isEndOfTrack, isFalse);
      expect(state.isDurationMode, isFalse);
      expect(state.selectedDuration, equals(const Duration(minutes: 30)));
      expect(state.remainingDuration, equals(Duration.zero));
      expect(state.fadeOutEnabled, isTrue);
    });

    test('selectDuration updates preset without prematurely activating', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.selectDuration(const Duration(minutes: 45));

      final state = container.read(sleepTimerProvider);
      expect(state.isEnabled, isFalse);
      expect(state.selectedDuration, equals(const Duration(minutes: 45)));
      expect(state.selectedMode, equals(SleepTimerMode.duration));

      // Now activate and verify it starts with chosen 45m preset
      notifier.activate();
      final activeState = container.read(sleepTimerProvider);
      expect(activeState.isEnabled, isTrue);
      expect(activeState.isDurationMode, isTrue);
      expect(activeState.remainingDuration, equals(const Duration(minutes: 45)));
    });

    test('deactivate stops countdown but preserves chosen preset', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.setDuration(const Duration(minutes: 60));
      expect(container.read(sleepTimerProvider).isEnabled, isTrue);

      notifier.deactivate();
      final state = container.read(sleepTimerProvider);
      expect(state.isEnabled, isFalse);
      expect(state.isActive, isFalse);
      expect(state.selectedDuration, equals(const Duration(minutes: 60)));
      expect(state.remainingDuration, equals(Duration.zero));
    });

    test('selectEndOfTrack updates preset and activates properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.selectEndOfTrack();
      expect(container.read(sleepTimerProvider).selectedMode, equals(SleepTimerMode.endOfTrack));

      notifier.activate();
      final activeState = container.read(sleepTimerProvider);
      expect(activeState.isEnabled, isTrue);
      expect(activeState.isEndOfTrack, isTrue);
    });

    test('setDuration arms duration mode directly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.setDuration(const Duration(minutes: 30));

      final state = container.read(sleepTimerProvider);
      expect(state.isActive, isTrue);
      expect(state.isEnabled, isTrue);
      expect(state.isDurationMode, isTrue);
      expect(state.isEndOfTrack, isFalse);
      expect(state.remainingDuration, equals(const Duration(minutes: 30)));
      expect(state.totalDuration, equals(const Duration(minutes: 30)));
    });

    test('addMinutes correctly extends duration timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.setDuration(const Duration(minutes: 15));
      notifier.addMinutes(5);

      final state = container.read(sleepTimerProvider);
      expect(state.remainingDuration, equals(const Duration(minutes: 20)));
      expect(state.totalDuration, equals(const Duration(minutes: 20)));
    });

    test('cancel disarms sleep timer back to disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.setDuration(const Duration(minutes: 45));
      expect(container.read(sleepTimerProvider).isActive, isTrue);

      notifier.cancel();
      final state = container.read(sleepTimerProvider);
      expect(state.isActive, isFalse);
      expect(state.isEnabled, isFalse);
      expect(state.remainingDuration, equals(Duration.zero));
    });

    test('triggerEndOfTrackStop resets timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sleepTimerProvider.notifier);
      notifier.setEndOfTrack();
      expect(container.read(sleepTimerProvider).isEndOfTrack, isTrue);

      notifier.triggerEndOfTrackStop();
      final state = container.read(sleepTimerProvider);
      expect(state.isActive, isFalse);
      expect(state.isEnabled, isFalse);
      expect(state.isEndOfTrack, isFalse);
    });

    test('Persistence across app restarts: restores chosen duration, mode, and fadeOut preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Session 1: User sets 45 min, End of Track, and disables fade-out
      final session1Container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      final notifier1 = session1Container.read(sleepTimerProvider.notifier);
      notifier1.selectDuration(const Duration(minutes: 45));
      notifier1.setFadeOut(false);
      notifier1.selectEndOfTrack();

      // Close session 1
      session1Container.dispose();

      // Session 2: User opens app again (fresh ProviderContainer initialized with same prefs)
      final session2Container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(session2Container.dispose);

      final restoredState = session2Container.read(sleepTimerProvider);
      expect(restoredState.selectedDuration, equals(const Duration(minutes: 45)));
      expect(restoredState.selectedMode, equals(SleepTimerMode.endOfTrack));
      expect(restoredState.fadeOutEnabled, isFalse);
      expect(restoredState.isEnabled, isFalse); // Session stays cleanly disabled until user taps activate
    });
  });

  group('SettingsSubView Navigation Tests', () {
    test('SettingsSubView enum includes preferences', () {
      expect(SettingsSubView.values, contains(SettingsSubView.preferences));
    });

    test('SettingsSubViewNotifier switches to preferences view and closes to none', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsSubViewProvider.notifier);
      expect(container.read(settingsSubViewProvider), equals(SettingsSubView.none));

      notifier.setSubView(SettingsSubView.preferences);
      expect(container.read(settingsSubViewProvider), equals(SettingsSubView.preferences));

      notifier.close();
      expect(container.read(settingsSubViewProvider), equals(SettingsSubView.none));
    });
  });

  group('PreferencesSection UI & Custom Sheet Keyboard / Mobile Tests', () {
    testWidgets('Custom sleep timer sheet supports typing hours and minutes via keyboard',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioProvider.overrideWith(_MockAudioNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getDarkTheme(null),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: PreferencesSection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Custom... bottom sheet
      final customChipFinder = find.text('Custom...');
      expect(customChipFinder, findsOneWidget);
      await tester.tap(customChipFinder);
      await tester.pumpAndSettle();

      // Verify FloatingSheetShell appeared with title and 2 text fields (Hours and Minutes)
      expect(find.text('Custom Sleep Timer'), findsOneWidget);
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Enter hours via keyboard
      final hoursField = textFields.first;
      await tester.tap(hoursField);
      await tester.pumpAndSettle();
      await tester.enterText(hoursField, '02');
      await tester.pumpAndSettle();

      // Enter minutes via keyboard
      final minutesField = textFields.last;
      await tester.tap(minutesField);
      await tester.pumpAndSettle();
      await tester.enterText(minutesField, '45');
      await tester.pumpAndSettle();

      // Verify live summary updates
      expect(find.text('Playback will stop after 2 hours and 45 minutes'), findsOneWidget);

      // Tap 'Set Timer'
      final setTimerButton = find.text('Set Timer');
      expect(setTimerButton, findsOneWidget);
      await tester.tap(setTimerButton);
      await tester.pumpAndSettle();

      // Verify custom duration was applied to state: 2h 45m = 165 minutes
      final timerState = container.read(sleepTimerProvider);
      expect(timerState.selectedDuration, equals(const Duration(hours: 2, minutes: 45)));
      expect(find.text('2h 45m'), findsOneWidget);
    });

    testWidgets('Custom sleep timer sheet is stable on phone viewport with active keyboard insets',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioProvider.overrideWith(_MockAudioNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      // Compact phone screen (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getDarkTheme(null),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: PreferencesSection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Custom...
      await tester.tap(find.text('Custom...'));
      await tester.pumpAndSettle();

      // Simulate on-screen virtual keyboard popping up (insets bottom = 280)
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();

      // Ensure no exceptions or overflows occurred
      expect(tester.takeException(), isNull);
      expect(find.text('Custom Sleep Timer'), findsOneWidget);
    });
  });
}
