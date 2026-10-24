import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_providers.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_top_bar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_top_bar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSidebarHarness({
    required Size screenSize,
    required Widget child,
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: Scaffold(
            body: SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Sidebar Mutual Exclusion Tests (< 1050px threshold)', () {
    testWidgets('Expanding left sidebar closes right sidebar when window width < 1050px', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Precondition: Right sidebar is expanded, Left sidebar is collapsed
      container.read(rightSidebarExpandedProvider.notifier).setExpanded(true);
      container.read(leftSidebarExpandedProvider.notifier).setExpanded(false);

      expect(container.read(rightSidebarExpandedProvider), isTrue);
      expect(container.read(leftSidebarExpandedProvider), isFalse);

      await tester.pumpWidget(
        buildSidebarHarness(
          screenSize: const Size(850, 600), // < 1050px
          container: container,
          child: const LeftSidebarTopBar(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Expand Navigation' button on LeftSidebarTopBar
      final expandLeftFinder = find.byWidgetPredicate(
        (w) => w is ReusableHoverIconButton && w.tooltip == 'Expand Navigation',
      );
      expect(expandLeftFinder, findsOneWidget);

      await tester.tap(expandLeftFinder);
      await tester.pumpAndSettle();

      // Left should now be expanded, and Right must have automatically closed
      expect(container.read(leftSidebarExpandedProvider), isTrue);
      expect(container.read(rightSidebarExpandedProvider), isFalse);
    });

    testWidgets('Expanding right sidebar closes left sidebar when window width < 1050px', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Precondition: Left sidebar is expanded, Right sidebar is collapsed
      container.read(leftSidebarExpandedProvider.notifier).setExpanded(true);
      container.read(rightSidebarExpandedProvider.notifier).setExpanded(false);

      expect(container.read(leftSidebarExpandedProvider), isTrue);
      expect(container.read(rightSidebarExpandedProvider), isFalse);

      await tester.pumpWidget(
        buildSidebarHarness(
          screenSize: const Size(900, 600), // < 1050px
          container: container,
          child: const RightSidebarTopBar(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Expand Sidebar' button on RightSidebarTopBar
      final expandRightFinder = find.byWidgetPredicate(
        (w) => w is ReusableHoverIconButton && w.tooltip == 'Expand Sidebar',
      );
      expect(expandRightFinder, findsOneWidget);

      await tester.tap(expandRightFinder);
      await tester.pumpAndSettle();

      // Right should now be expanded, and Left must have automatically closed
      expect(container.read(rightSidebarExpandedProvider), isTrue);
      expect(container.read(leftSidebarExpandedProvider), isFalse);
    });

    testWidgets('Both sidebars can remain expanded when window width >= 1050px', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Precondition: Right sidebar is expanded, Left sidebar is collapsed
      container.read(rightSidebarExpandedProvider.notifier).setExpanded(true);
      container.read(leftSidebarExpandedProvider.notifier).setExpanded(false);

      await tester.pumpWidget(
        buildSidebarHarness(
          screenSize: const Size(1280, 800), // >= 1050px
          container: container,
          child: const LeftSidebarTopBar(),
        ),
      );
      await tester.pumpAndSettle();

      final expandLeftFinder = find.byWidgetPredicate(
        (w) => w is ReusableHoverIconButton && w.tooltip == 'Expand Navigation',
      );
      expect(expandLeftFinder, findsOneWidget);

      await tester.tap(expandLeftFinder);
      await tester.pumpAndSettle();

      // On wide screens, BOTH sidebars remain expanded simultaneously
      expect(container.read(leftSidebarExpandedProvider), isTrue);
      expect(container.read(rightSidebarExpandedProvider), isTrue);
    });
  });

  group('TopNavigationHeader Overflow Immunity Tests', () {
    testWidgets('TopNavigationHeader fits within constrained 280.9px width without RenderFlex overflow', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Sized to exactly the 280.9px width from the original layout exception
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280.9,
                  child: TopNavigationHeader(
                    left: const Text('Home'),
                    actions: [
                      ReusableHoverIconButton(
                        icon: UIcons.regular.refresh,
                        tooltip: 'Refresh feed',
                        iconSize: 18,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No exception thrown, and Home text is rendered
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
