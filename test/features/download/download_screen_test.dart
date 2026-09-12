import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/download/data/models/download_item.dart';
import 'package:resonance/features/download/presentation/screens/download_screen.dart';
import 'package:resonance/features/download/application/providers/download_provider.dart';
import 'package:resonance/features/download/application/providers/download_settings_provider.dart';

class FakeDownloadNotifier extends DownloadNotifier {
  @override
  List<DownloadItem> build() => [];

  @override
  void addToQueue(
    List<String> urls, {
    DownloadType type = DownloadType.audio,
    DownloadSource source = DownloadSource.ytmusic,
    yt.Video? video,
  }) {}
}

class _FakeDownloadSettingsNotifier extends DownloadSettingsNotifier {
  @override
  Future<DownloadSettings> build() async {
    return const DownloadSettings(
      musicOutputPath: 'C:\\Music\\Resonance Downloads',
      videoOutputPath: 'C:\\Videos\\Resonance Downloads',
    );
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        downloadProvider.overrideWith(FakeDownloadNotifier.new),
        downloadSettingsProvider.overrideWith(_FakeDownloadSettingsNotifier.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadScreen(showHeader: true),
        ),
      ),
    );
  }

  group('DownloadScreen UI & Dynamic Input Detection', () {
    testWidgets('renders input panel and does not display obsolete Android banner', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the input panel exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);

      // Verify obsolete Android banner is NOT present
      expect(find.textContaining('Direct URL downloads require the desktop Python bridge'), findsNothing);
    });

    testWidgets('displays YouTube Music format badge when YT Music URL is typed', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(
        find.byType(TextField),
        'https://music.youtube.com/watch?v=2zPGWGqdfJ8',
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('YouTube Music (Audio)'), findsOneWidget);
    });

    testWidgets('displays warning and disables Add button when unsupported URL is entered', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(
        find.byType(TextField),
        'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT',
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Unsupported link (open.spotify.com)'), findsOneWidget);

      // Verify Add to Queue button is disabled
      final button = tester.widget<ResonanceButton>(find.byType(ResonanceButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('displays playlist guidance banner when playlist URL is typed', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(
        find.byType(TextField),
        'https://www.youtube.com/playlist?list=PL1234567890',
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('YouTube Playlist'), findsOneWidget);
      expect(find.textContaining('Playlist link detected'), findsOneWidget);
    });

    testWidgets('displays Song Search badge when song title is typed', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(
        find.byType(TextField),
        'Queen - Bohemian Rhapsody',
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Song Search (Top match)'), findsOneWidget);
    });
  });
}
