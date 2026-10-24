import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/widgets/text/resonance_marquee_text.dart';
import 'package:resonance/features/explore/data/models/explore_playlist.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_playlist_card_tile.dart';
import 'package:resonance/features/explore/presentation/widgets/recent_searches_card.dart';
import 'package:resonance/features/home/presentation/widgets/hover_track_card.dart';
import 'package:resonance/features/home/presentation/widgets/quick_picks_track_tile.dart';
import 'package:resonance/features/home/presentation/widgets/speed_dial_card.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

class _FakeAudioNotifier extends AudioNotifier {
  @override
  AudioState build() => AudioState();
}

class _FakeLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() => LibraryState();
}

class _FakePlaylistNotifier extends PlaylistNotifier {
  @override
  Future<PlaylistState> build() async => const PlaylistState(playlists: []);
  @override
  bool isLiked(MediaItem track) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final mockTrack = MediaItem(
    id: 'test_123',
    title: 'Extremely Long Song Title That Overflows The Standard Container Width',
    artist: 'Very Long Artist Name Collaborating With Multiple Other Artists',
    path: 'http://example.com/test.mp3',
    type: 'audio',
  );

  Widget buildTestable(Widget child, {double width = 300, double height = 500}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioProvider.overrideWith(() => _FakeAudioNotifier()),
        libraryProvider.overrideWith(_FakeLibraryNotifier.new),
        playlistProvider.overrideWith(() => _FakePlaylistNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Marquee Restriction and Reversion Tests', () {
    testWidgets('HoverTrackCard uses static Text with ellipsis (zero ResonanceMarqueeText)', (tester) async {
      await tester.pumpWidget(buildTestable(HoverTrackCard(track: mockTrack)));
      await tester.pump();

      expect(find.byType(ResonanceMarqueeText), findsNothing);
      expect(find.text(mockTrack.title), findsOneWidget);
      expect(find.text(mockTrack.artist!), findsOneWidget);
    });

    testWidgets('QuickPicksTrackTile uses static Text with ellipsis (zero ResonanceMarqueeText)', (tester) async {
      await tester.pumpWidget(buildTestable(
        QuickPicksTrackTile(item: mockTrack, subtitleInfo: 'Custom Subtitle Text'),
      ));
      await tester.pump();

      expect(find.byType(ResonanceMarqueeText), findsNothing);
      expect(find.text(mockTrack.title), findsOneWidget);
      expect(find.text('Custom Subtitle Text'), findsOneWidget);
    });

    testWidgets('SpeedDialCard uses static Text with ellipsis (zero ResonanceMarqueeText)', (tester) async {
      await tester.pumpWidget(buildTestable(SpeedDialCard(item: mockTrack)));
      await tester.pump();

      expect(find.byType(ResonanceMarqueeText), findsNothing);
      expect(find.text(mockTrack.title), findsOneWidget);
    });

    testWidgets('RecentSearchesCard uses static Text with ellipsis (zero ResonanceMarqueeText)', (tester) async {
      await tester.pumpWidget(buildTestable(RecentSearchesCard(item: mockTrack)));
      await tester.pump();

      expect(find.byType(ResonanceMarqueeText), findsNothing);
      expect(find.text(mockTrack.title), findsOneWidget);
    });

    testWidgets('ExplorePlaylistCardTile uses static Text with ellipsis (zero ResonanceMarqueeText)', (tester) async {
      final mockPlaylist = ExplorePlaylist(
        id: 'pl_123',
        title: 'Super Long Curated YouTube Music Playlist That Would Overflow',
        author: 'Major Record Label Discovery Curator',
        thumbnailUrl: '',
        videoCount: 50,
      );

      await tester.pumpWidget(buildTestable(ExplorePlaylistCardTile(playlist: mockPlaylist)));
      await tester.pump();

      expect(find.byType(ResonanceMarqueeText), findsNothing);
      expect(find.text(mockPlaylist.title), findsOneWidget);
      expect(find.text(mockPlaylist.author), findsOneWidget);
    });

    testWidgets('MediaActionsBottomSheet uses ResonanceMarqueeText for track title (1 of 5 allowed areas)', (tester) async {
      tester.view.physicalSize = const Size(500, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestable(
        MediaActionsBottomSheet(item: mockTrack),
        width: 500,
        height: 700,
      ));
      await tester.pump();

      final marquees = find.byType(ResonanceMarqueeText);
      expect(marquees, findsOneWidget);

      final titleWidget = tester.widget<ResonanceMarqueeText>(marquees.first);
      expect(titleWidget.text, equals(mockTrack.title));
    });
  });
}
