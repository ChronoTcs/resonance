import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio/mobile_media_import_card.dart';
import 'package:resonance/features/playlist/presentation/widgets/import_playlist_sheet.dart';

void main() {
  group('ImportPlaylistSheet Responsive Platform Tests', () {
    testWidgets('Renders drag-and-drop drop zone on desktop platforms', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.windows),
            home: const Scaffold(
              body: ImportPlaylistSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On desktop, drag & drop text exists
      expect(find.text('Drag & drop a .json playlist file here'), findsOneWidget);
      // Mobile card does not exist
      expect(find.byType(MobileMediaImportCard), findsNothing);
    });

    testWidgets('Renders MobileMediaImportCard without drag-and-drop on Android', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: const Scaffold(
              body: ImportPlaylistSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On Android, MobileMediaImportCard exists
      expect(find.byType(MobileMediaImportCard), findsOneWidget);
      expect(find.text('Browse Playlist File'), findsOneWidget);
      expect(find.text('JSON PLAYLIST FILE'), findsOneWidget);

      // Desktop drag & drop text does not exist
      expect(find.text('Drag & drop a .json playlist file here'), findsNothing);
    });
  });
}
