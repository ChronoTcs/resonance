import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/core/widgets/layout/app_back_button.dart';
import 'package:resonance/features/explore/data/models/explore_item.dart';
import 'package:resonance/features/explore/data/models/explore_playlist.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/explore/presentation/screens/online_playlist_detail_screen.dart';

class _FakeYoutubePlaylistRepository implements YoutubePlaylistRepository {
  final List<ExploreItem> stubbedItems;

  _FakeYoutubePlaylistRepository(this.stubbedItems);

  @override
  Future<List<ExplorePlaylist>> fetchMyPlaylists() async => [];

  @override
  Future<List<ExploreItem>> fetchFullPlaylistContents(String input) async {
    return stubbedItems;
  }

  @override
  Future<bool> editYouTubePlaylist(
    String playlistId,
    String videoId, {
    required bool isAdd,
    String? setVideoId,
  }) async =>
      true;
}

class _FakeMediaCacheService extends Fake implements MediaCacheService {
  @override
  Future<String?> getCachedArtPath(String songId) async => null;
}

class _MockNetworkNotifier extends NetworkConnectivityNotifier {
  final bool _online;
  _MockNetworkNotifier([this._online = true]);

  @override
  NetworkConnectivityState build() {
    return NetworkConnectivityState(isOnline: _online);
  }
}

void main() {
  group('SelectedExplorePlaylistNotifier', () {
    test('initial state is null and updates correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedExplorePlaylistProvider), isNull);

      const playlist = ExplorePlaylist(
        id: 'PL12345',
        title: 'Top Hits',
        author: 'Vibe Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoCount: 25,
      );

      container.read(selectedExplorePlaylistProvider.notifier).setSelected(playlist);
      expect(container.read(selectedExplorePlaylistProvider), playlist);

      container.read(selectedExplorePlaylistProvider.notifier).setSelected(null);
      expect(container.read(selectedExplorePlaylistProvider), isNull);
    });
  });

  group('onlinePlaylistTracksProvider', () {
    test('returns empty when offline', () async {
      final container = ProviderContainer(
        overrides: [
          networkConnectivityProvider.overrideWith(() => _MockNetworkNotifier(false)),
        ],
      );
      addTearDown(container.dispose);

      final tracks = await container.read(onlinePlaylistTracksProvider('PL12345').future);
      expect(tracks, isEmpty);
    });

    test('fetches and maps tracks when online', () async {
      final stubbedExploreItems = [
        ExploreItem(
          id: 'v1',
          title: 'Track 1',
          author: 'Artist 1',
          album: 'Album 1',
          duration: '3:30',
          thumbnailUrl: 'https://example.com/v1.jpg',
          url: 'https://youtube.com/watch?v=v1',
          type: 'audio',
        ),
        ExploreItem(
          id: 'v2',
          title: 'Track 2',
          author: 'Artist 2',
          album: 'Album 2',
          duration: '4:15',
          thumbnailUrl: 'https://example.com/v2.jpg',
          url: 'https://youtube.com/watch?v=v2',
          type: 'audio',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          networkConnectivityProvider.overrideWith(() => _MockNetworkNotifier(true)),
          youtubePlaylistRepositoryProvider.overrideWithValue(
            _FakeYoutubePlaylistRepository(stubbedExploreItems),
          ),
        ],
      );
      addTearDown(container.dispose);

      final tracks = await container.read(onlinePlaylistTracksProvider('PL12345').future);
      expect(tracks.length, 2);
      expect(tracks.first.id, 'v1');
      expect(tracks.first.title, 'Track 1');
      expect(tracks.first.artist, 'Artist 1');
      expect(tracks.first.album, 'Album 1');
      expect(tracks.first.thumbnailUrl, 'https://example.com/v1.jpg');
      expect(tracks.first.isStreaming, isTrue);

      expect(tracks[1].id, 'v2');
      expect(tracks[1].title, 'Track 2');
    });
  });

  group('OnlinePlaylistDetailScreen Widget', () {
    testWidgets('renders playlist header, actions, and back button clears selection', (tester) async {
      const playlist = ExplorePlaylist(
        id: 'PL999',
        title: 'Synthwave 80s',
        author: 'Retro Wave',
        thumbnailUrl: '',
        videoCount: 10,
      );

      final stubbedExploreItems = [
        ExploreItem(
          id: 's1',
          title: 'Nightcall',
          author: 'Kavinsky',
          duration: '4:19',
          thumbnailUrl: '',
          url: 'https://youtube.com/watch?v=s1',
          type: 'audio',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          networkConnectivityProvider.overrideWith(() => _MockNetworkNotifier(true)),
          youtubePlaylistRepositoryProvider.overrideWithValue(
            _FakeYoutubePlaylistRepository(stubbedExploreItems),
          ),
          mediaCacheServiceProvider.overrideWithValue(
            _FakeMediaCacheService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedExplorePlaylistProvider.notifier).setSelected(playlist);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OnlinePlaylistDetailScreen(playlist: playlist),
          ),
        ),
      );

      // Settle async fetch
      await tester.pumpAndSettle();

      expect(find.text('Synthwave 80s'), findsOneWidget);
      expect(find.text('Retro Wave'), findsOneWidget);
      expect(find.text('1 track'), findsOneWidget);
      expect(find.text('Nightcall'), findsOneWidget);
      expect(find.text('Kavinsky'), findsOneWidget);

      // Verify back button clears selectedExplorePlaylistProvider
      final backButton = find.byType(AppBackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(container.read(selectedExplorePlaylistProvider), isNull);
    });
  });
}

