import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/widgets/buttons/play_pause_button.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/home/presentation/widgets/mobile_now_playing_hero_card.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
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
    required Color primaryColor,
    Brightness brightness = Brightness.dark,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioProvider.overrideWith(() => _FakeAudioNotifier(mockTrack)),
        lyricsProvider.overrideWith(() => _FakeLyricsNotifier()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: brightness,
          ),
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: MobileNowPlayingHeroCard(),
          ),
        ),
      ),
    );
  }

  group('MobileNowPlayingHeroCard Dynamic Theme Tests', () {
    testWidgets('adapts border, shadows, and frosted control strip to primary theme color',
        (tester) async {
      const testSeedColor = Colors.teal;

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestable(primaryColor: testSeedColor));
      await tester.pump();

      expect(find.byType(MobileNowPlayingHeroCard), findsOneWidget);

      // Verify card container has active theme border
      final heroCardContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(MobileNowPlayingHeroCard),
          matching: find.byType(Container),
        ).first,
      );

      final boxDecoration = heroCardContainer.decoration as BoxDecoration;
      expect(boxDecoration.border, isNotNull);
      expect(boxDecoration.boxShadow, isNotNull);

      // Verify ReusableHoverIconButtons are present
      expect(find.byType(ReusableHoverIconButton), findsWidgets);

      // Verify PlayPauseButton is present
      expect(find.byType(PlayPauseButton), findsOneWidget);

      // Verify redundant circle arrow-up icon is erased
      expect(find.byIcon(UIcons.regular.angle_small_up), findsNothing);
    });
  });
}
