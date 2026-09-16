import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/explore/presentation/screens/explore_screen.dart';
import 'package:resonance/features/home/presentation/widgets/adaptive_home_header.dart';

class _MockNetworkNotifier extends NetworkConnectivityNotifier {
  @override
  NetworkConnectivityState build() {
    return const NetworkConnectivityState(isOnline: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Search Bar Clear vs Cancel Tests (Phase 19 & 20)', () {
    testWidgets('AdaptiveHomeHeader: shows search and refresh icons when closed', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveHomeHeader(
              isCompact: true,
              isSearchFieldOpen: false,
              searchController: controller,
              onSubmitSearch: (_) {},
              onToggleSearch: () {},
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Verify title is visible
      expect(find.text('Resonance'), findsOneWidget);
      // Verify Search icon is visible
      expect(find.byIcon(UIcons.regular.search), findsOneWidget);
      // Verify Refresh icon is visible
      expect(find.byIcon(UIcons.regular.refresh), findsOneWidget);
      // Verify Cancel button is NOT visible
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('AdaptiveHomeHeader: hides refresh icon and shows Cancel when search is open', (tester) async {
      final controller = TextEditingController();
      bool toggleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveHomeHeader(
              isCompact: true,
              isSearchFieldOpen: true,
              searchController: controller,
              onSubmitSearch: (_) {},
              onToggleSearch: () {
                toggleCalled = true;
              },
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Verify search field is open
      expect(find.byType(TextField), findsOneWidget);
      // Verify Refresh icon is HIDDEN
      expect(find.byIcon(UIcons.regular.refresh), findsNothing);
      // Verify Cancel button is VISIBLE
      expect(find.text('Cancel'), findsOneWidget);

      // Tapping Cancel should invoke onToggleSearch
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(toggleCalled, isTrue);
    });

    testWidgets('AdaptiveHomeHeader: inline cross icon erases text only without closing search', (tester) async {
      final controller = TextEditingController();
      bool toggleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AdaptiveHomeHeader(
                  isCompact: true,
                  isSearchFieldOpen: true,
                  searchController: controller,
                  onSubmitSearch: (_) {},
                  onToggleSearch: () {
                    toggleCalled = true;
                  },
                  onRefresh: () {},
                );
              },
            ),
          ),
        ),
      );

      // Initially empty: cross_small suffix icon should not be visible
      expect(find.byIcon(UIcons.regular.cross_small), findsNothing);

      // Type some text into the search field
      await tester.enterText(find.byType(TextField), 'Radiohead');
      await tester.pump();

      expect(controller.text, equals('Radiohead'));
      // Now suffix icon cross_small should be visible
      expect(find.byIcon(UIcons.regular.cross_small), findsOneWidget);

      // Tap the cross_small clear icon
      await tester.tap(find.byIcon(UIcons.regular.cross_small));
      await tester.pump();

      // Verify text was erased
      expect(controller.text, isEmpty);
      // Verify search bar was NOT closed (onToggleSearch not called)
      expect(toggleCalled, isFalse);
      // Verify TextField is still present
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ExploreScreen: inline clear button erases text but keeps mobile search open', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            networkConnectivityProvider.overrideWith(() => _MockNetworkNotifier()),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially shows Explore title and search icon
      expect(find.text('Explore'), findsOneWidget);
      expect(find.byIcon(UIcons.regular.search), findsOneWidget);

      // Tap search icon to open search bar
      await tester.tap(find.byIcon(UIcons.regular.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Search TextField and Cancel button are visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Nirvana');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Clear icon [✕] should be visible
      expect(find.byIcon(UIcons.regular.cross_small), findsOneWidget);

      // Tap clear icon [✕]
      await tester.tap(find.byIcon(UIcons.regular.cross_small));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Critical assertion: TextField and Cancel button MUST STILL BE VISIBLE!
      // The search bar must NOT collapse to 'Explore' title!
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextField, ''), findsOneWidget);

      // Now tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now it collapses back to 'Explore' title
      expect(find.text('Explore'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Flush pending network connectivity check timer (4s)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('ExploreScreen: allows editing existing query after submission without resetting', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          networkConnectivityProvider.overrideWith(() => _MockNetworkNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Open search bar
      await tester.tap(find.byIcon(UIcons.regular.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 2. Type "beautiful" and submit
      await tester.enterText(find.byType(TextField), 'beautiful');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify search query submitted
      expect(container.read(searchQueryProvider), equals('beautiful'));
      expect(find.widgetWithText(TextField, 'beautiful'), findsOneWidget);

      // 3. User taps TextField to edit, appending " bazzi"
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'beautiful bazzi');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Critical assertion: TextField MUST retain "beautiful bazzi" and NOT revert to "beautiful"!
      expect(find.widgetWithText(TextField, 'beautiful bazzi'), findsOneWidget);

      // 4. Submit updated query
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(searchQueryProvider), equals('beautiful bazzi'));

      await tester.pump(const Duration(seconds: 5));
    });
  });
}

