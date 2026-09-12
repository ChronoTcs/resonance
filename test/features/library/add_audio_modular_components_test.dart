import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/constants/audio_constants.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio/audio_file_drop_card.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio/batch_import_progress_card.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio/drop_zone_action_button.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio/mobile_media_import_card.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio/add_audio_shortcut_cards.dart';
import 'package:resonance/features/library/presentation/widgets/add_audio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAudioFormats Central Source of Truth Tests', () {
    test('Recognizes all standard audio extensions regardless of case', () {
      final supportedSamples = [
        'track.mp3',
        'song.FLAC',
        'audio.Wav',
        'voice.ogg',
        'podcast.opus',
        'stream.aac',
        'recording.m4a',
        'legacy.wma',
      ];

      for (final path in supportedSamples) {
        expect(AppAudioFormats.isSupported(path), isTrue, reason: 'Expected $path to be supported');
      }
    });

    test('Rejects non-audio extensions', () {
      final unsupportedSamples = [
        'video.mp4',
        'document.pdf',
        'script.py',
        'archive.zip',
        'image.png',
      ];

      for (final path in unsupportedSamples) {
        expect(AppAudioFormats.isSupported(path), isFalse, reason: 'Expected $path to be rejected');
      }
    });

    test('Contains correct dot and raw extension lists', () {
      expect(AppAudioFormats.rawExtensions, containsAll(['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'wma']));
      expect(AppAudioFormats.dotExtensions, containsAll(['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.wma']));
      expect(AppAudioFormats.formatListLabel, equals('MP3, FLAC, M4A, WAV, OGG, OPUS, AAC, WMA'));
    });
  });

  group('DropZoneActionButton Widget Tests', () {
    testWidgets('Renders label, icon, and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.dark(primary: Colors.amber),
          ),
          home: Scaffold(
            body: DropZoneActionButton(
              icon: Icons.folder_open_rounded,
              label: 'Scan Folder',
              isPrimary: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Scan Folder'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);

      await tester.tap(find.text('Scan Folder'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('BatchImportProgressCard Widget Tests', () {
    testWidgets('Displays current progress, total tracks, and linear indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatchImportProgressCard(
              current: 25,
              total: 100,
            ),
          ),
        ),
      );

      expect(find.text('Importing tracks (25 of 100)...'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('AddAudioSheet Modular Composition Tests', () {
    testWidgets('Renders on desktop with AudioFileDropCard, shortcuts, and divider', (tester) async {
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

      expect(find.byType(AudioFileDropCard), findsOneWidget);
      expect(find.byType(ExploreShortcutCard), findsOneWidget);
      expect(find.byType(DownloadsShortcutCard), findsOneWidget);
      expect(find.byType(SheetDivider), findsOneWidget);
    });

    testWidgets('Renders on mobile viewport with MobileMediaImportCard and shortcuts', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: const Scaffold(
              body: AddAudioSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MobileMediaImportCard), findsNWidgets(2));
      expect(find.byType(AudioFileDropCard), findsNothing);
      expect(find.byType(ExploreShortcutCard), findsOneWidget);
      expect(find.byType(DownloadsShortcutCard), findsOneWidget);
    });
  });
}
