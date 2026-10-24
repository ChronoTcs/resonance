import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/widgets/buttons/play_pause_button.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
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
        audioProvider.overrideWith(() => _FakeAudioNotifier(track ?? mockTrack)),
        lyricsProvider.overrideWith(() => _FakeLyricsNotifier()),
        lyricsTranslationProvider
            .overrideWith(() => _FakeLyricsTranslationNotifier()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          platform: platform,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Now Playing Android Layout Refactor Tests', () {
    testWidgets('NavigationControlCard with isCard: false has no card decoration',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          platform: TargetPlatform.android,
          child: const NavigationControlCard(
            showSeekSlider: true,
            showVolumeSlider: false,
            isLargePlayButton: true,
            isCard: false,
          ),
        ),
      );
      await tester.pump();

      // Find Container inside RepaintBoundary of NavigationControlCard
      final containerFinder = find.descendant(
        of: find.byType(NavigationControlCard),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsWidgets);
      final firstContainer = tester.widget<Container>(containerFinder.first);
      // When isCard == false, decoration must be null (fused with view)
      expect(firstContainer.decoration, isNull);
    });

    testWidgets(
        'NavigationControlCard with isLargePlayButton renders PlayPauseButton without circle container',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          platform: TargetPlatform.android,
          child: const NavigationControlCard(
            showSeekSlider: true,
            showVolumeSlider: false,
            isLargePlayButton: true,
            isCard: false,
          ),
        ),
      );
      await tester.pump();

      // Must render PlayPauseButton
      expect(find.byType(PlayPauseButton), findsOneWidget);

      // Verify no circular container background exists for play button
      final containers = tester.widgetList<Container>(find.descendant(
        of: find.byType(PlayPauseButton),
        matching: find.byType(Container),
      ));
      for (final c in containers) {
        if (c.decoration is BoxDecoration) {
          final box = c.decoration as BoxDecoration;
          expect(box.shape, isNot(equals(BoxShape.circle)));
        }
      }
    });

    testWidgets('Android Now Playing screen artwork has zero floating plus badges',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestable(
          platform: TargetPlatform.android,
          child: const NowPlayingScreen(),
        ),
      );
      await tester.pump();

      // Verify ReusableHoverIconButton exists for "Add to playlist" in track action row
      final addButtons = find.byWidgetPredicate(
        (w) => w is ReusableHoverIconButton && w.tooltip == 'Add to playlist',
      );
      expect(addButtons, findsOneWidget);

      // Verify zero BackdropFilter badges exist on artwork thumbnail
      final artworkBackdropFilters = find.descendant(
        of: find.byType(AspectRatio),
        matching: find.byType(BackdropFilter),
      );
      expect(artworkBackdropFilters, findsNothing);
    });
  });
}
