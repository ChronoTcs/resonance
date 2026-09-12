import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/widgets/text/resonance_marquee_text.dart';

void main() {
  testWidgets('ResonanceMarqueeText renders short text without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: ResonanceMarqueeText(
              text: 'Short Title',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Short Title'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('ResonanceMarqueeText renders long text and updates when text changes', (tester) async {
    String currentText = 'A Very Long Song Title That Exceeds The Width Of Mini Player Box';

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 100,
                    child: ResonanceMarqueeText(
                      text: currentText,
                      velocity: 50.0,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentText = 'New Track Title';
                      });
                    },
                    child: const Text('Change Track'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    expect(find.text(currentText), findsOneWidget);

    // Tap button to change track
    await tester.tap(find.text('Change Track'));
    await tester.pump();

    expect(find.text('New Track Title'), findsOneWidget);
  });
}
