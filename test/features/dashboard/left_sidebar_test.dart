import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_nav_item.dart';
import 'package:resonance/features/dashboard/presentation/widgets/left_sidebar/left_sidebar_top_bar.dart';

void main() {
  testWidgets('LeftSidebar renders shrunk rail (50px) by default', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LeftSidebar(),
          ),
        ),
      ),
    );

    expect(find.byType(LeftSidebarTopBar), findsOneWidget);
    expect(find.byType(LeftSidebarNavItem), findsNWidgets(6));
    expect(find.text('Resonance'), findsNothing);
    expect(find.text('RECOMMEND'), findsNothing);
    expect(find.text('MY MUSIC'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Expand Navigation'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('LeftSidebar expands and displays section headers and titles when expanded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leftSidebarExpandedProvider.overrideWith(() => _MockExpandedNotifier(true)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LeftSidebar(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resonance'), findsOneWidget);
    expect(find.text('RECOMMEND'), findsOneWidget);
    expect(find.text('MY MUSIC'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Collapse Navigation'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('LeftSidebar navigation items update mainNavigationProvider on tap', (tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: LeftSidebar(),
          ),
        ),
      ),
    );

    expect(container.read(mainNavigationProvider), 0);

    // Tap Explore item (index 1)
    await tester.tap(find.byType(LeftSidebarNavItem).at(1));
    await tester.pumpAndSettle();

    expect(container.read(mainNavigationProvider), 1);

    // Tap Settings item (index 5)
    await tester.tap(find.byType(LeftSidebarNavItem).at(5));
    await tester.pumpAndSettle();

    expect(container.read(mainNavigationProvider), 5);
  });
}

class _MockExpandedNotifier extends LeftSidebarExpandedNotifier {
  final bool initialValue;
  _MockExpandedNotifier(this.initialValue);

  @override
  bool build() => initialValue;
}
