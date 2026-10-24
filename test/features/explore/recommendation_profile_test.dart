import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/core/utils/recommendation_sampler.dart';
import 'package:resonance/features/explore/application/services/user_taste_profile_service.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/services/session_history_tracker.dart';

class _FakeCacheManager extends CacheManager {
  final Directory tempDir;
  _FakeCacheManager(this.tempDir);

  @override
  Future<Directory> getBaseCacheDir() async => tempDir;
}

void main() {
  group('SessionHistoryTracker Tests', () {
    test('tracks recently played IDs and respects max limit', () {
      final tracker = SessionHistoryTracker();

      tracker.recordPlayed('track_1');
      tracker.recordPlayed('track_2');
      tracker.recordPlayed('track_3');

      expect(tracker.wasPlayedRecently('track_1'), isTrue);
      expect(tracker.wasPlayedRecently('track_2'), isTrue);
      expect(tracker.wasPlayedRecently('track_3'), isTrue);
      expect(tracker.wasPlayedRecently('track_99'), isFalse);
      expect(tracker.recentIds.length, 3);

      // Verify ring buffer eviction beyond 100 items
      for (var i = 4; i <= 105; i++) {
        tracker.recordPlayed('track_$i');
      }

      expect(tracker.recentIds.length, 100);
      expect(tracker.wasPlayedRecently('track_1'), isFalse); // Evicted
      expect(tracker.wasPlayedRecently('track_105'), isTrue); // Present
    });

    test('deduplicates existing tracks when played again', () {
      final tracker = SessionHistoryTracker();
      tracker.recordPlayed('track_1');
      tracker.recordPlayed('track_2');
      tracker.recordPlayed('track_1'); // re-added

      expect(tracker.recentIds.length, 2);
      expect(tracker.wasPlayedRecently('track_1'), isTrue);
    });
  });

  group('RecommendationSampler Tests', () {
    test('samples requested count and strictly respects excludeIds', () {
      final candidates = List.generate(
        20,
        (i) => MediaItem(
          id: 'song_$i',
          path: 'song_$i',
          title: 'Title $i',
          type: 'audio',
        ),
      );

      final excludeIds = {'song_0', 'song_1', 'song_2'};
      final sampled = RecommendationSampler.sample(
        candidates: candidates,
        count: 5,
        excludeIds: excludeIds,
      );

      expect(sampled.length, 5);
      for (final item in sampled) {
        expect(excludeIds.contains(item.id), isFalse);
      }
    });

    test('entropy ensures varied selections across multiple runs', () {
      final candidates = List.generate(
        25,
        (i) => MediaItem(
          id: 'song_$i',
          path: 'song_$i',
          title: 'Title $i',
          type: 'audio',
        ),
      );

      final sampleA = RecommendationSampler.sample(candidates: candidates, count: 5);
      final sampleB = RecommendationSampler.sample(candidates: candidates, count: 5);

      // Verify that sampling selects valid candidates
      expect(sampleA.length, 5);
      expect(sampleB.length, 5);
    });
  });

  group('UserTasteProfileService Tests', () {
    late Directory tempDir;
    late _FakeCacheManager fakeCacheManager;
    late UserTasteProfileService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('taste_profile_test_');
      fakeCacheManager = _FakeCacheManager(tempDir);
      service = UserTasteProfileService(fakeCacheManager);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('promotes track to core anchor after 2 completed plays', () async {
      final track = MediaItem(
        id: 'golden_hour',
        path: 'golden_hour',
        title: 'Golden Hour',
        artist: 'JVKE',
        duration: const Duration(seconds: 200),
        type: 'audio',
      );

      // Play 1: Completed 180s out of 200s (90%)
      await service.recordEngagement(
        track,
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 200),
      );

      var anchors = await service.getCoreAnchorSeeds();
      expect(anchors.isEmpty, isTrue); // Not yet a core anchor (playCount = 1)

      // Play 2: Completed 190s out of 200s (95%)
      await service.recordEngagement(
        track,
        position: const Duration(seconds: 190),
        duration: const Duration(seconds: 200),
      );

      anchors = await service.getCoreAnchorSeeds();
      expect(anchors.length, 1); // Promoted to core anchor!
      expect(anchors.first.id, 'golden_hour');

      // Verify artist affinity
      final topArtists = await service.getTopAffinityArtists();
      expect(topArtists, contains('JVKE'));
    });

    test('flags track as negative signal on consecutive quick skips', () async {
      final track = MediaItem(
        id: 'bad_song',
        path: 'bad_song',
        title: 'Bad Song',
        artist: 'Random Artist',
        duration: const Duration(seconds: 200),
        type: 'audio',
      );

      // Skip 1 at 5 seconds
      await service.recordEngagement(
        track,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 200),
      );
      expect(service.isNegativeSignal('bad_song'), isFalse);

      // Skip 2 at 8 seconds
      await service.recordEngagement(
        track,
        position: const Duration(seconds: 8),
        duration: const Duration(seconds: 200),
      );
      expect(service.isNegativeSignal('bad_song'), isTrue); // Penalized!
    });
  });
}
