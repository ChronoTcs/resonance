import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance/features/lyrics/application/lyrics_translation_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/screens/now_playing_screen.dart';
import 'package:resonance/features/player/presentation/widgets/player_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioNotifier extends AudioNotifier {
  final MediaItem? _track;
  _FakeAudioNotifier([this._track]);

  @override
  AudioState build() => AudioState(
        currentTrack: _track,
        duration: const Duration(minutes: 3),
        position: const Duration(seconds: 45),
        isPlaying: false,
      );
}

class _FakeLyricsNotifier extends LyricsNotifier {
  @override
  LyricsState build() => LyricsState();
}

class _FakeLyricsTranslationNotifier extends LyricsTranslationNotifier {
  @override
  LyricsTranslationState build() => LyricsTranslationState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final mockTrack = MediaItem(
    id: 'compact_test_track',
    title: 'Compact Test Track',
    artist: 'Test Artist',
    album: 'Test Album',
    path: 'https://example.com/test.mp3',
    type: 'audio',
  );

  Widget buildTestable({
    required Size screenSize,
    TargetPlatform platform = TargetPlatform.windows,
    MediaItem? track,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioProvider
            .overrideWith(() => _FakeAudioNotifier(track ?? mockTrack)),
        lyricsProvider.overrideWith(() => _FakeLyricsNotifier()),
        lyricsTranslationProvider
            .overrideWith(() => _FakeLyricsTranslationNotifier()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          platform: platform,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: Scaffold(
            body: SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: const NowPlayingScreen(),
            ),
          ),
        ),
      ),
    );
  }

  group('NowPlayingScreen Desktop Compact Layout Tests', () {
    testWidgets('renders 2-column split on compact desktop (550x380)',
        (tester) async {
      tester.view.physicalSize = const Size(550, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestable(screenSize: const Size(550, 380)),
      );
      await tester.pumpAndSettle();

      // Verify no overflow errors
      expect(tester.takeException(), isNull);

      // Verify MetadataCard, MiniLyricsCard, NextInQueueCard are all rendered
      expect(find.byType(MetadataCard), findsOneWidget);
      expect(find.byType(MiniLyricsCard), findsOneWidget);
      expect(find.byType(NextInQueueCard), findsOneWidget);

      // Verify artwork card size is clamped and <= 210px
      final metadataCardRenderBox =
          tester.renderObject(find.byType(MetadataCard)) as RenderBox;
      final lyricsCardRenderBox =
          tester.renderObject(find.byType(MiniLyricsCard)) as RenderBox;

      // In 2-column layout, MetadataCard (left pane) and MiniLyricsCard (right pane) have different X positions
      final metadataPos = metadataCardRenderBox.localToGlobal(Offset.zero);
      final lyricsPos = lyricsCardRenderBox.localToGlobal(Offset.zero);

      expect(metadataPos.dx, lessThan(lyricsPos.dx),
          reason: 'MetadataCard must be to the left of MiniLyricsCard in 2-column split');

      // Verify artwork card dimensions are clamped <= 210px
      final artworkFinder = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(Hero),
      );
      expect(artworkFinder, findsWidgets);

      final artworkRenderBox =
          tester.renderObject(artworkFinder.first) as RenderBox;
      expect(artworkRenderBox.size.width, lessThanOrEqualTo(210.0),
          reason: 'Artwork width must not exceed 210px limit');
      expect(artworkRenderBox.size.height, lessThanOrEqualTo(210.0),
          reason: 'Artwork height must not exceed 210px limit');

      // Verify MiniLyricsCard dynamically expands beyond old hardcoded 200px
      expect(lyricsCardRenderBox.size.height, greaterThanOrEqualTo(230.0),
          reason: 'MiniLyricsCard should dynamically expand beyond old 200px limit');
    });

    testWidgets('renders single-column fallback on extremely narrow desktop (< 420px)',
        (tester) async {
      tester.view.physicalSize = const Size(380, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestable(screenSize: const Size(380, 500)),
      );
      await tester.pumpAndSettle();

      // Verify no overflow errors
      expect(tester.takeException(), isNull);

      // In narrow mode, cards should be vertically stacked (same or aligned X position)
      final metadataCardRenderBox =
          tester.renderObject(find.byType(MetadataCard)) as RenderBox;
      final lyricsCardRenderBox =
          tester.renderObject(find.byType(MiniLyricsCard)) as RenderBox;

      final metadataPos = metadataCardRenderBox.localToGlobal(Offset.zero);
      final lyricsPos = lyricsCardRenderBox.localToGlobal(Offset.zero);

      expect(metadataPos.dx, equals(lyricsPos.dx),
          reason: 'In stacked narrow fallback, left edges should align vertically');

      // Artwork card clamped <= 190px (380 * 0.5 = 190 max)
      final artworkFinder = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(Hero),
      );
      final artworkRenderBox =
          tester.renderObject(artworkFinder.first) as RenderBox;
      expect(artworkRenderBox.size.width, lessThanOrEqualTo(190.0));
    });
  });
}

