import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/exceptions/offline_exception.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/services/stream_resolution_service.dart';
import 'package:resonance/features/player/application/services/playback_architecture_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_stream_repository.dart';

class ThrowingOfflineStreamRepo implements YoutubeStreamRepository {
  @override
  Future<String?> getStreamUrl(String videoId) async {
    throw const OfflinePlaybackException('Device is offline and no cached audio is available.');
  }

  @override
  Future<void> warmUpSession() async {}

  @override
  void dispose() {}
}

class MockOfflineNetworkNotifier extends NetworkConnectivityNotifier {
  @override
  NetworkConnectivityState build() {
    return const NetworkConnectivityState(isOnline: false);
  }
}

class MockLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() => LibraryState();
}

class MockAudioNotifier extends AudioNotifier {
  List<MediaItem> playedPlaylist = [];
  bool shuffleEnabled = false;

  @override
  AudioState build() => AudioState();

  @override
  Future<void> playPlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
    String? playlistId,
  }) async {
    playedPlaylist = List.from(items);
    state = state.copyWith(queue: items, isShuffleEnabled: shuffleEnabled);
  }

  @override
  void setShuffle(bool enabled) {
    shuffleEnabled = enabled;
    state = state.copyWith(isShuffleEnabled: enabled);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryProvider.overrideWith(MockLibraryNotifier.new),
        audioProvider.overrideWith(MockAudioNotifier.new),
        youtubeStreamRepositoryProvider.overrideWithValue(ThrowingOfflineStreamRepo()),
        networkConnectivityProvider.overrideWith(MockOfflineNetworkNotifier.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Offline Playback Exception Preservation & Resolution Tests', () {
    test('PlaybackArchitectureService rethrows OfflinePlaybackException', () async {
      final archService = container.read(playbackArchitectureServiceProvider);

      expect(
        () => archService.getStreamUrl('test_song_123'),
        throwsA(isA<OfflinePlaybackException>()),
      );
    });

    test('StreamResolutionService throws OfflinePlaybackException when offline and uncached', () async {
      final resolver = container.read(streamResolutionServiceProvider);
      final streamingTrack = MediaItem(
        id: 'yt_stream_unseen',
        title: 'Online Track',
        path: 'https://youtube.com/watch?v=yt_stream_unseen',
        type: 'audio',
      );

      expect(
        () => resolver.resolve(streamingTrack),
        throwsA(isA<OfflinePlaybackException>()),
      );
    });
  });

  group('QueueOrchestrator Offline Radio Fallback Tests', () {
    test('playOfflineRadioFallback constructs queue from cached stream music and local pool', () async {
      final cachedTracks = [
        MediaItem(id: 'cached_1', title: 'Cached Song 1', path: '/cache/1.m4a', type: 'audio'),
        MediaItem(id: 'cached_2', title: 'Cached Song 2', path: '/cache/2.m4a', type: 'audio'),
      ];
      final localTracks = [
        MediaItem(id: 'local_1', title: 'Local Song 1', path: '/music/1.mp3', type: 'audio'),
      ];

      final orchestratorContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryProvider.overrideWith(MockLibraryNotifier.new),
          audioProvider.overrideWith(MockAudioNotifier.new),
          cachedStreamMusicProvider.overrideWith((ref) async => cachedTracks),
        ],
      );

      final failedTrack = MediaItem(
        id: 'failed_online_track',
        title: 'Unplayable Song',
        path: 'https://youtube.com/watch?v=failed_online_track',
        type: 'audio',
      );

      final orchestrator = orchestratorContainer.read(queueOrchestratorProvider);
      orchestrator.playOfflineRadioFallback(
        failedTrack: failedTrack,
        localTracks: localTracks,
        cachedTracks: cachedTracks,
      );

      final audioState = orchestratorContainer.read(audioProvider);

      // Verify failed track was excluded
      expect(audioState.queue.any((t) => t.id == 'failed_online_track'), isFalse);
      // Verify queue contains cached and local tracks
      expect(audioState.queue.length, equals(3));
      final ids = audioState.queue.map((t) => t.id).toSet();
      expect(ids, containsAll({'cached_1', 'cached_2', 'local_1'}));
      // Verify shuffle is enabled for radio experience
      expect(audioState.isShuffleEnabled, isTrue);

      orchestratorContainer.dispose();
    });

    test('playOfflineRadioFallback respects blocked tracks', () async {
      final cachedTracks = [
        MediaItem(id: 'cached_good', title: 'Good Song', path: '/cache/good.m4a', type: 'audio'),
        MediaItem(id: 'cached_blocked', title: 'Blocked Song', path: '/cache/blocked.m4a', type: 'audio'),
      ];

      final orchestratorContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryProvider.overrideWith(MockLibraryNotifier.new),
          audioProvider.overrideWith(MockAudioNotifier.new),
          cachedStreamMusicProvider.overrideWith((ref) async => cachedTracks),
        ],
      );

      // Block cached_blocked
      await orchestratorContainer.read(blockedTracksProvider.notifier).blockTrack(cachedTracks[1]);

      final orchestrator = orchestratorContainer.read(queueOrchestratorProvider);
      orchestrator.playOfflineRadioFallback(
        localTracks: [],
        cachedTracks: cachedTracks,
      );

      final audioState = orchestratorContainer.read(audioProvider);
      expect(audioState.queue.length, equals(1));
      expect(audioState.queue.first.id, equals('cached_good'));

      orchestratorContainer.dispose();
    });
  });
}
