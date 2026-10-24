import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/widgets/overlays/blur_transition_overlay.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('MiniPlayer Instant-Cut Transition & State Tests', () {
    test('MiniPlayerPopNotifier initial state is not popped and normal view', () {
      final state = container.read(miniPlayerPopProvider);
      expect(state.isPopped, isFalse);
      expect(state.viewState, MiniPlayerViewState.normal);
      expect(state.originalSize, isNull);
    });

    test('MiniPlayerPopNotifier setViewState updates view state safely', () {
      final notifier = container.read(miniPlayerPopProvider.notifier);
      
      // When not popped, setViewState is a no-op guard
      notifier.setViewState(MiniPlayerViewState.hover);
      expect(container.read(miniPlayerPopProvider).viewState, MiniPlayerViewState.normal);
    });

    test('MiniPlayerPopState copyWith immutability works as expected', () {
      final initial = MiniPlayerPopState();
      final updated = initial.copyWith(
        isPopped: true,
        viewState: MiniPlayerViewState.lyrics,
        wasMaximized: true,
      );

      expect(updated.isPopped, isTrue);
      expect(updated.viewState, MiniPlayerViewState.lyrics);
      expect(updated.wasMaximized, isTrue);
      expect(initial.isPopped, isFalse);
    });
    testWidgets('BlurTransitionLayer mounts and defaults to inactive', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BlurTransitionLayer(),
            ),
          ),
        ),
      );

      expect(find.byType(BlurTransitionLayer), findsOneWidget);
      expect(find.byKey(const ValueKey('blur_off')), findsOneWidget);
      expect(find.byKey(const ValueKey('blur_on')), findsNothing);
    });
  });
}
