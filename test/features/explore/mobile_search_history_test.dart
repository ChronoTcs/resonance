import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/explore/presentation/widgets/mobile_search_history_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'explore_search_history': jsonEncode(['Billie Eilish', 'Taylor Swift', 'Coldplay']),
    });
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Widget buildTestWidget({
    required ValueChanged<String> onSelect,
    required ValueChanged<String> onInsert,
    String filterText = '',
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: MobileSearchHistorySection(
            onSelect: onSelect,
            onInsert: onInsert,
            filterText: filterText,
          ),
        ),
      ),
    );
  }

  group('MobileSearchHistorySection Tests', () {
    testWidgets('renders recent search queries with clock icons and action buttons', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSelect: (_) {},
          onInsert: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Header and Clear all
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      // Query items
      expect(find.text('Billie Eilish'), findsOneWidget);
      expect(find.text('Taylor Swift'), findsOneWidget);
      expect(find.text('Coldplay'), findsOneWidget);

      // Icons
      expect(find.byIcon(Icons.arrow_outward), findsAtLeastNWidgets(3));
      expect(find.byIcon(UIcons.regular.cross_small), findsNWidgets(3));
    });

    testWidgets('tapping query row triggers onSelect with query string', (tester) async {
      String? selectedQuery;
      await tester.pumpWidget(
        buildTestWidget(
          onSelect: (q) => selectedQuery = q,
          onInsert: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Taylor Swift'));
      await tester.pump();

      expect(selectedQuery, equals('Taylor Swift'));
    });

    testWidgets('tapping insert icon triggers onInsert with query string', (tester) async {
      String? insertedQuery;
      await tester.pumpWidget(
        buildTestWidget(
          onSelect: (_) {},
          onInsert: (q) => insertedQuery = q,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the second insert icon (Taylor Swift)
      await tester.tap(find.byIcon(Icons.arrow_outward).at(1));
      await tester.pump();

      expect(insertedQuery, equals('Taylor Swift'));
    });

    testWidgets('tapping cross remove icon deletes specific query from history', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSelect: (_) {},
          onInsert: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coldplay'), findsOneWidget);

      // Tap cross icon for the third item (Coldplay)
      await tester.tap(find.byIcon(UIcons.regular.cross_small).at(2));
      await tester.pumpAndSettle();

      // Coldplay should now be gone
      expect(find.text('Coldplay'), findsNothing);
      expect(find.text('Billie Eilish'), findsOneWidget);
      expect(find.text('Taylor Swift'), findsOneWidget);
    });

    testWidgets('tapping Clear all clears all search history', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSelect: (_) {},
          onInsert: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('Billie Eilish'), findsNothing);
      expect(find.text('Taylor Swift'), findsNothing);
      expect(find.text('Coldplay'), findsNothing);
    });

    testWidgets('filters history items when filterText is provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSelect: (_) {},
          onInsert: (_) {},
          filterText: 'taylor',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matching searches'), findsOneWidget);
      expect(find.text('Taylor Swift'), findsOneWidget);
      expect(find.text('Billie Eilish'), findsNothing);
      expect(find.text('Coldplay'), findsNothing);
    });
  });
}
