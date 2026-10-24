import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/card_hover_play_button.dart';

void main() {
  group('CardHoverPlayButton Tests', () {
    testWidgets('renders play icon with no background container box', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardHoverPlayButton(
                isPlaying: false,
                isLoading: false,
                iconSize: 36.0,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify Icon is play icon
      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, equals(UIcons.regular.play));
      expect(icon.size, equals(36.0));

      // Verify no decorated background boxes or circles exist in CardHoverPlayButton
      expect(find.byType(Container), findsNothing);

      // Tap triggers callback
      await tester.tap(iconFinder);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders pause icon when isPlaying is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardHoverPlayButton(
                isPlaying: true,
                isLoading: false,
                iconSize: 44.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, equals(UIcons.regular.pause));
      expect(icon.size, equals(44.0));
    });

    testWidgets('renders CircularProgressIndicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardHoverPlayButton(
                isPlaying: false,
                isLoading: true,
                iconSize: 32.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('scales on mouse hover without background shapes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardHoverPlayButton(
                isPlaying: false,
                isLoading: false,
                iconSize: 36.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final animatedScaleFinder = find.byType(AnimatedScale);
      expect(animatedScaleFinder, findsOneWidget);
      AnimatedScale scaleWidget = tester.widget<AnimatedScale>(animatedScaleFinder);
      expect(scaleWidget.scale, equals(1.0));

      // Simulate mouse hover enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(CardHoverPlayButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      scaleWidget = tester.widget<AnimatedScale>(animatedScaleFinder);
      expect(scaleWidget.scale, equals(1.18));

      // Leave hover
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      scaleWidget = tester.widget<AnimatedScale>(animatedScaleFinder);
      expect(scaleWidget.scale, equals(1.0));
    });
  });
}
