import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/data/services/discord_rpc_service.dart';
import 'package:resonance/features/library/data/models/media_item.dart' as app_models;
import 'package:resonance/features/player/application/services/gapless_prefetch_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_search_repository.dart';
import 'package:resonance/features/explore/data/services/youtube_innertube_client.dart';
import 'package:resonance/features/player/data/services/audio_metadata_service.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/audio_handler.dart';

class MockOfflineNetworkNotifier extends NetworkConnectivityNotifier {
  @override
  NetworkConnectivityState build() {
    return const NetworkConnectivityState(isOnline: false);
  }
}

class MockAudioNotifier extends AudioNotifier {
  @override
  AudioState build() => AudioState();
}

class MockAudioHandler extends BaseAudioHandler implements ResonanceAudioHandler {
  @override
  Player get player => throw UnimplementedError();

  @override
  VoidCallback? onSkipToNext;

  @override
  VoidCallback? onSkipToPrevious;
}

class FakeInnerTubeClient implements YoutubeInnerTubeClient {
  bool postCalled = false;

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> payload, {
    YoutubeClientProfile profile = YoutubeClientProfile.webRemix,
    bool useAuth = false,
    String? poToken,
    int? signatureTimestamp,
  }) async {
    postCalled = true;
    throw Exception('InnerTube HTTP post should never be called when offline!');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;
  late FakeInnerTubeClient fakeClient;
  late MockAudioHandler mockAudioHandler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeClient = FakeInnerTubeClient();
    mockAudioHandler = MockAudioHandler();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        networkConnectivityProvider.overrideWith(MockOfflineNetworkNotifier.new),
        audioProvider.overrideWith(MockAudioNotifier.new),
        youtubeInnerTubeClientProvider.overrideWithValue(fakeClient),
        audioHandlerProvider.overrideWithValue(mockAudioHandler),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Background Services Offline Guards (Phase 17)', () {
    test('DiscordRpcService skips iTunes network fetch when offline', () async {
      final rpcService = container.read(discordRpcServiceProvider);
      final track = app_models.MediaItem(
        id: 'test_song',
        title: 'Test Song',
        artist: 'Test Artist',
        path: 'https://youtube.com/watch?v=test_song',
        type: 'audio',
      );

      final res = await rpcService.resolveArtworkAndMetadata(track);
      expect(res.artworkUrl, isNull);
      expect(res.albumName, isNull);

      final fullInfo = await rpcService.resolveFullTrackInfo('Test Song', 'Test Artist');
      expect(fullInfo.artworkUrl, isNull);
      expect(fullInfo.albumName, isNull);
      expect(fullInfo.trackTitle, isNull);
      expect(fullInfo.artistName, isNull);
      expect(fullInfo.releaseDate, isNull);
    });

    test('YoutubeSearchRepository skips network calls when offline', () async {
      final repo = container.read(youtubeSearchRepositoryProvider);

      final recs = await repo.getRadioRecommendations('seed_video_id');
      expect(recs, isEmpty);
      expect(fakeClient.postCalled, isFalse);

      final searchItems = await repo.search('test query');
      expect(searchItems, isEmpty);
      expect(fakeClient.postCalled, isFalse);

      final searchPlaylists = await repo.searchPlaylists('playlist query');
      expect(searchPlaylists, isEmpty);
      expect(fakeClient.postCalled, isFalse);
    });

    test('GaplessPrefetchService aborts proactiveFetch immediately when offline', () async {
      final prefetchService = container.read(gaplessPrefetchServiceProvider);

      // Calling proactiveFetch when offline should immediately return and reset locks
      await prefetchService.proactiveFetch();
      expect(() => prefetchService.resetLock(), returnsNormally);
    });

    test('AudioMetadataService suppresses remote HTTP artUri when offline and uncached', () async {
      final metadataService = container.read(audioMetadataServiceProvider);
      final track = app_models.MediaItem(
        id: 'offline_song_uncached',
        title: 'Offline Song',
        artist: 'Offline Artist',
        thumbnailUrl: 'https://i.ytimg.com/vi/offline_song/mqdefault.jpg',
        path: 'https://youtube.com/watch?v=offline_song_uncached',
        type: 'audio',
      );

      // onTrackChanged should execute safely without network attempts
      await metadataService.onTrackChanged(track, isPlaying: true);

      // MediaItem artUri should be null because device is offline and no local cached artwork exists
      expect(mockAudioHandler.mediaItem.value?.artUri, isNull);
    });
  });
}

