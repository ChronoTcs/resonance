import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/layout/resonance_segmented_bar.dart';

void main() {
  group('ResonanceSegmentedBar Widget Tests', () {
    testWidgets('2-item layout splits width equally (50/50)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResonanceSegmentedBar(
              items: const [
                ResonanceSegmentItem(label: 'Music'),
                ResonanceSegmentItem(label: 'Playlists'),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final musicFinder = find.text('Music');
      final playlistsFinder = find.text('Playlists');

      expect(musicFinder, findsOneWidget);
      expect(playlistsFinder, findsOneWidget);

      // Both items are in Expanded(flex: 1) containers, verify their ancestors are equal width
      final musicContainer = tester.renderObject(
        find.ancestor(of: musicFinder, matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;
      final playlistsContainer = tester.renderObject(
        find.ancestor(of: playlistsFinder, matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;

      expect((musicContainer.size.width - playlistsContainer.size.width).abs(), lessThan(1.0));
      expect(musicContainer.size.width, greaterThan(140.0));
    });

    testWidgets('3-item layout splits width equally (33.3% each)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResonanceSegmentedBar(
              items: const [
                ResonanceSegmentItem(label: 'Music'),
                ResonanceSegmentItem(label: 'Playlists'),
                ResonanceSegmentItem(label: 'Downloads', isDismissible: true),
              ],
              selectedIndex: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final musicFinder = find.text('Music');
      final playlistsFinder = find.text('Playlists');
      final downloadsFinder = find.text('Downloads');

      expect(musicFinder, findsOneWidget);
      expect(playlistsFinder, findsOneWidget);
      expect(downloadsFinder, findsOneWidget);

      final musicBox = tester.renderObject(
        find.ancestor(of: musicFinder, matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;
      final playlistsBox = tester.renderObject(
        find.ancestor(of: playlistsFinder, matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;
      final downloadsBox = tester.renderObject(
        find.ancestor(of: downloadsFinder, matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;

      expect((musicBox.size.width - playlistsBox.size.width).abs(), lessThan(1.0));
      expect((musicBox.size.width - downloadsBox.size.width).abs(), lessThan(1.0));
      expect(musicBox.size.width, greaterThan(90.0));
    });

    testWidgets('Tap selection fires onSelected callback', (tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResonanceSegmentedBar(
              items: const [
                ResonanceSegmentItem(label: 'Music'),
                ResonanceSegmentItem(label: 'Playlists'),
              ],
              selectedIndex: selected,
              onSelected: (index) {
                selected = index;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();

      expect(selected, equals(1));
    });

    testWidgets('Dismiss icon button fires onDismiss callback', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResonanceSegmentedBar(
              items: [
                const ResonanceSegmentItem(label: 'Music'),
                const ResonanceSegmentItem(label: 'Playlists'),
                ResonanceSegmentItem(
                  label: 'Downloads',
                  isDismissible: true,
                  onDismiss: () {
                    dismissed = true;
                  },
                ),
              ],
              selectedIndex: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final dismissIcon = find.byIcon(UIcons.regular.cross_small);
      expect(dismissIcon, findsOneWidget);

      await tester.tap(dismissIcon);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('Dynamic morphing from 2 to 3 items smoothly animates and adjusts sizes', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool showDownloads = false;

      Widget buildTestWidget() {
        return MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ResonanceSegmentedBar(
                  items: [
                    const ResonanceSegmentItem(label: 'Music'),
                    const ResonanceSegmentItem(label: 'Playlists'),
                    if (showDownloads)
                      const ResonanceSegmentItem(
                        label: 'Downloads',
                        isDismissible: true,
                      ),
                  ],
                  selectedIndex: showDownloads ? 2 : 0,
                  onSelected: (_) {},
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTestWidget());
      expect(find.text('Downloads'), findsNothing);

      showDownloads = true;
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Downloads'), findsOneWidget);

      final musicBox = tester.renderObject(
        find.ancestor(of: find.text('Music'), matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;
      expect(musicBox.size.width, greaterThan(90.0));
      expect(musicBox.size.width, lessThan(120.0));
    });

    testWidgets('Icon-only dismissible segment renders without label text and splits 33.3%', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResonanceSegmentedBar(
              items: [
                const ResonanceSegmentItem(label: 'Music'),
                const ResonanceSegmentItem(label: 'Playlists'),
                ResonanceSegmentItem(
                  label: '',
                  icon: UIcons.regular.download,
                  tooltip: 'Downloads',
                  isDismissible: true,
                ),
              ],
              selectedIndex: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // Downloads text must not be rendered (preventing ellipsis)
      expect(find.text('Downloads'), findsNothing);
      expect(find.byIcon(UIcons.regular.download), findsOneWidget);
      expect(find.byIcon(UIcons.regular.cross_small), findsOneWidget);

      final musicBox = tester.renderObject(
        find.ancestor(of: find.text('Music'), matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;
      final dlBox = tester.renderObject(
        find.ancestor(of: find.byIcon(UIcons.regular.download), matching: find.byType(AnimatedContainer)).first,
      ) as RenderBox;

      expect((musicBox.size.width - dlBox.size.width).abs(), lessThan(1.0));
    });
  });
}
