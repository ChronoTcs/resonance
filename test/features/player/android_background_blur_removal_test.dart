import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/widgets/media/media_artwork_widget.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance/features/lyrics/application/lyrics_translation_provider.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/screens/now_playing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioNotifier extends AudioNotifier {
  final MediaItem? _track;
  _FakeAudioNotifier([this._track]);

  @override
  AudioState build() => AudioState(currentTrack: _track);
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
    id: 'test_song',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    path: 'https://example.com/song.mp3',
    type: 'audio',
  );

  Widget buildTestable({
    required Widget child,
    required TargetPlatform platform,
    MediaItem? track,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioProvider.overrideWith(() => _FakeAudioNotifier(track)),
        lyricsProvider.overrideWith(() => _FakeLyricsNotifier()),
        lyricsTranslationProvider.overrideWith(() => _FakeLyricsTranslationNotifier()),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Android Background Blur Removal Tests', () {
    testWidgets('NowPlayingScreen removes blurred thumbnail background on Android', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          child: const NowPlayingScreen(),
          platform: TargetPlatform.android,
          track: mockTrack,
        ),
      );
      await tester.pumpAndSettle();

      // On Android, 80-sigma background BackdropFilter must not be present
      final backgroundBlurFinder = find.byWidgetPredicate(
        (w) => w is BackdropFilter && w.filter.toString().contains('80.0'),
      );
      expect(backgroundBlurFinder, findsNothing);
    });

    testWidgets('NowPlayingScreen removes blurred thumbnail background on Desktop / Windows', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          child: const NowPlayingScreen(),
          platform: TargetPlatform.windows,
          track: mockTrack,
        ),
      );
      await tester.pumpAndSettle();

      // On non-Android (Windows), BackdropFilter is removed to eliminate GPU Gaussian blur overhead
      final backgroundBlurFinder = find.byWidgetPredicate(
        (w) => w is BackdropFilter && w.filter.toString().contains('80.0'),
      );
      expect(backgroundBlurFinder, findsNothing);
    });

    testWidgets('LyricsScreen (embedded) removes BackdropFilter and background artwork on Android', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          child: const LyricsScreen(isEmbedded: true),
          platform: TargetPlatform.android,
          track: mockTrack,
        ),
      );
      await tester.pumpAndSettle();

      // On Android, neither BackdropFilter nor background MediaArtworkWidget should render
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(MediaArtworkWidget), findsNothing);
    });

    testWidgets('LyricsScreen (embedded) removes BackdropFilter on Desktop / Windows', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          child: const LyricsScreen(isEmbedded: true),
          platform: TargetPlatform.windows,
          track: mockTrack,
        ),
      );
      await tester.pumpAndSettle();

      // On Windows, BackdropFilter is removed to eliminate GPU Gaussian blur overhead
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('NowPlayingScreen and LyricsScreen render ambient accent gradient on Android', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          child: const NowPlayingScreen(),
          platform: TargetPlatform.android,
          track: mockTrack,
        ),
      );
      await tester.pumpAndSettle();

      final npGradientFinder = find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient is LinearGradient,
      );
      expect(npGradientFinder, findsWidgets);

      await tester.pumpWidget(
        buildTestable(
          child: const LyricsScreen(isEmbedded: true),
          platform: TargetPlatform.android,
          track: mockTrack,
        ),
      );
      await tester.pumpAndSettle();

      final lyricsGradientFinder = find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient is LinearGradient,
      );
      expect(lyricsGradientFinder, findsWidgets);
    });
  });
}
