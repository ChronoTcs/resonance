import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/search_history_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'explore_search_history': jsonEncode(['radiohead', 'oasis']),
    });
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget({required WidgetRefCallback onRef}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          onRef(ref);
          return MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const TopNavigationHeader(),
                  Expanded(
                    child: Container(
                      key: const Key('outside_area'),
                      color: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  group('TopNavigationHeader Unified Search Bar Tests', () {
    testWidgets('Focusing search field with history opens unified dropdown', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestWidget(onRef: (_) {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Search box exists
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // History should not be visible before focus
      expect(find.text('radiohead'), findsNothing);

      // Tap to focus
      await tester.tap(searchField);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // History items and Clear Search History should now be visible
      expect(find.text('radiohead'), findsOneWidget);
      expect(find.text('oasis'), findsOneWidget);
      expect(find.text('Clear Search History'), findsOneWidget);
    });

    testWidgets('Tapping outside dismisses overlay immediately via TapRegion', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestWidget(onRef: (_) {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Focus
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('radiohead'), findsOneWidget);

      // Tap outside
      await tester.tap(find.byKey(const Key('outside_area')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should be immediately gone
      expect(find.text('radiohead'), findsNothing);
    });

    testWidgets('Changing tab via navigationProvider immediately dismisses overlay', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        buildTestWidget(onRef: (ref) => capturedRef = ref),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Focus
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('radiohead'), findsOneWidget);

      // Simulate tab switch (e.g. from Explore index 1 to Library index 2)
      capturedRef.read(mainNavigationProvider.notifier).setIndex(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should be immediately dismissed
      expect(find.text('radiohead'), findsNothing);
    });

    testWidgets('Tapping Clear Search History clears history and closes overlay', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        buildTestWidget(onRef: (ref) => capturedRef = ref),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Focus
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Clear Search History'), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('Clear Search History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // History is empty and overlay is closed
      expect(find.text('radiohead'), findsNothing);
      expect(capturedRef.read(searchHistoryProvider), isEmpty);
    });
  });
}

typedef WidgetRefCallback = void Function(WidgetRef ref);
