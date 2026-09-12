import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/player/presentation/widgets/queue/queue_buffer_selector.dart';
import 'package:resonance/features/player/presentation/widgets/queue/queue_header_bar.dart';

void main() {
  group('QueueHeaderBar Layout Tests', () {
    testWidgets('Compact width (360px): title and count badge display cleanly', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QueueHeaderBar(
                totalUpcoming: 20,
                onClose: () {},
                onClearUpcoming: () {},
              ),
            ),
          ),
        ),
      );

      final textFinder = find.text('Queue');
      expect(textFinder, findsOneWidget);

      final badgeFinder = find.text('20');
      expect(badgeFinder, findsOneWidget);

      final renderParagraph = tester.renderObject(textFinder) as RenderBox;
      expect(renderParagraph.size.width, greaterThan(40.0));
    });

    testWidgets('Wide desktop width (890px): verify positions of right controls', (tester) async {
      tester.view.physicalSize = const Size(890, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QueueHeaderBar(
                totalUpcoming: 20,
                onClose: () {},
                onClearUpcoming: () {},
              ),
            ),
          ),
        ),
      );

      final selectorFinder = find.byType(QueueBufferSelector);
      expect(selectorFinder, findsOneWidget);

      final trashFinder = find.descendant(
        of: find.byType(QueueHeaderBar),
        matching: find.byType(ReusableHoverIconButton),
      ).last;
      final trashBox = tester.renderObject(trashFinder) as RenderBox;
      final trashTopLeft = trashBox.localToGlobal(Offset.zero);
      // Right edge of trash button must reach 870.0 (890 - 20 padding)
      expect(trashTopLeft.dx + trashBox.size.width, equals(870.0));

      final headerBarFinder = find.byType(QueueHeaderBar);
      final headerBox = tester.renderObject(headerBarFinder) as RenderBox;
      expect(headerBox.size.width, equals(890.0));
    });
  });
}
