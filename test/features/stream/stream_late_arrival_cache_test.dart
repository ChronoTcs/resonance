import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/services/playback_architecture_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_stream_repository.dart';

class _FakeYoutubeStreamRepo implements YoutubeStreamRepository {
  int fetchCount = 0;

  @override
  Future<String?> getStreamUrl(String videoId, {bool forceRefresh = false}) async {
    fetchCount++;
    return 'https://rr1---sn.googlevideo.com/videoplayback?expire=1999999999&id=$videoId';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CachedStreamInfo', () {
    test('correctly parses expiration from YouTube expire param and evaluates isExpired', () {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final info = CachedStreamInfo(
        'https://rr1---sn.googlevideo.com/videoplayback?expire=$futureTimestamp&id=test',
        DateTime.now(),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(futureTimestamp * 1000),
      );
      expect(info.isExpired, isFalse);

      final pastTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 60;
      final expiredInfo = CachedStreamInfo(
        'https://rr1---sn.googlevideo.com/videoplayback?expire=$pastTimestamp&id=test',
        DateTime.now().subtract(const Duration(hours: 3)),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(pastTimestamp * 1000),
      );
      expect(expiredInfo.isExpired, isTrue);
    });
  });

  group('PlaybackArchitectureService cacheStreamUrl (Late Arrival Salvage)', () {
    late ProviderContainer container;
    late _FakeYoutubeStreamRepo fakeRepo;

    setUp(() {
      fakeRepo = _FakeYoutubeStreamRepo();
      container = ProviderContainer(
        overrides: [
          youtubeStreamRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('stores stream URL into memory cache and avoids repository fetch', () async {
      final archService = container.read(playbackArchitectureServiceProvider);
      const videoId = 'dQw4w9WgXcQ';
      final futureExpiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 7200;
      final salvageUrl = 'https://rr5---sn.googlevideo.com/videoplayback?expire=$futureExpiry&id=$videoId';

      // Manually salvage late-arriving URL into cache
      archService.cacheStreamUrl(videoId, salvageUrl);

      // Verify that getStreamUrl returns the salvaged URL directly without calling the repo
      final result = await archService.getStreamUrl(videoId);
      expect(result, equals(salvageUrl));
      expect(fakeRepo.fetchCount, equals(0)); // Zero network fetches triggered
    });
  });
}
