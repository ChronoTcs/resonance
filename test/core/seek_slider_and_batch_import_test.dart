import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/widgets/inputs/reusable_seek_slider.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seek Slider & Thumb Shape Tests', () {
    test('RetroSliderThumbShape maintains signature rectangular dimensions (12x20, r4)', () {
      const thumb = RetroSliderThumbShape();
      expect(thumb.width, equals(12.0));
      expect(thumb.height, equals(20.0));
      expect(thumb.radius, equals(4.0));
      expect(thumb.getPreferredSize(true, false), equals(const Size(12.0, 20.0)));
    });

    testWidgets('ReusableSeekSlider renders cleanly with theme background fill and accent track', (tester) async {
      double sliderValue = 30.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.dark(primary: Colors.amber),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ReusableSeekSlider(
                  value: sliderValue,
                  max: 100.0,
                  onChanged: (val) => sliderValue = val,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(ReusableSeekSlider), findsOneWidget);

      // Drag slider
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pump();
      expect(sliderValue, greaterThan(30.0));
    });
  });

  group('AddAudioSheet Windows Action Buttons Tests', () {
    testWidgets('AddAudioSheet displays explicit Browse Files and Scan Folder buttons with drop zone', (tester) async {
      // Set desktop-like size
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.windows),
            home: const Scaffold(
              body: AddAudioSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify explicit Windows Drop Area declarations
      expect(find.text('Drag & drop audio files or folders here'), findsOneWidget);
      expect(find.text('Drop single tracks, albums, or entire music folders from File Explorer'), findsOneWidget);

      // Verify dedicated action buttons
      expect(find.text('Browse Files'), findsOneWidget);
      expect(find.text('Scan Folder'), findsOneWidget);
    });
  });
}
