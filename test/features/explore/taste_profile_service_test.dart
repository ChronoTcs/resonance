import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/core/data/services/stream_cache_tracker_service.dart';
import 'package:resonance/features/explore/application/services/taste_profile_service.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

class _FakeTrackerService extends StreamCacheTrackerService {
  final List<String> fakeTopIds;
  _FakeTrackerService(this.fakeTopIds) : super(CacheManager());

  @override
  Future<List<String>> getTopPlayedIds({int limit = 10, Duration? withinDuration}) async {
    return fakeTopIds.take(limit).toList();
  }
}

class _MockRecentlyPlayedNotifier extends RecentlyPlayedNotifier {
  final List<MediaItem> items;
  _MockRecentlyPlayedNotifier(this.items);

  @override
  Future<List<MediaItem>> build() async => items;
}

void main() {
  test('TasteProfileService getQuickPickSeeds prioritizes top played tracks and recent history', () async {
    final trackA = MediaItem(
      id: 'track_A',
      title: 'Song A (Repeated Many Times)',
      artist: 'Artist Alpha',
      path: 'track_A',
      type: 'audio',
    );
    final trackB = MediaItem(
      id: 'track_B',
      title: 'Song B (Played Once Recently)',
      artist: 'Artist Beta',
      path: 'track_B',
      type: 'audio',
    );
    final trackC = MediaItem(
      id: 'track_C',
      title: 'Song C (Played Recently)',
      artist: 'Artist Gamma',
      path: 'track_C',
      type: 'audio',
    );

    final container = ProviderContainer(
      overrides: [
        streamCacheTrackerServiceProvider.overrideWithValue(_FakeTrackerService(['track_A'])),
        recentlyPlayedProvider.overrideWith(() => _MockRecentlyPlayedNotifier([trackB, trackC, trackA])),
      ],
    );
    addTearDown(container.dispose);

    final tasteService = container.read(tasteProfileServiceProvider);
    final seeds = await tasteService.getQuickPickSeeds(limit: 3);

    expect(seeds.length, 3);
    // Track A has top play count, so it must be prioritized first
    expect(seeds.first.id, 'track_A');
    expect(seeds.map((s) => s.id).toList(), containsAll(['track_A', 'track_B', 'track_C']));
  });
}
