import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import '../../data/repositories/youtube_search_repository.dart';
import '../../data/models/explore_item.dart';
import '../../data/models/explore_playlist.dart';
import '../../data/models/explore_home.dart';
import '../../../player/application/providers/audio_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../../application/services/taste_profile_service.dart';

// re-export from core so existing callers of explore_provider don't break
export 'package:resonance/core/providers/search_provider.dart'
    show searchQueryProvider, searchStateProvider, SearchQueryNotifier, SearchStateNotifier;

final homeFeedProvider = FutureProvider<List<ExploreHomeSection>>((ref) async {
  // Offline guard — return empty immediately, no timeout waste
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  final repo = ref.read(youtubeSearchRepositoryProvider);
  return repo.getHomeFeed();
});


final searchResultsProvider = FutureProvider<List<ExploreItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];

  final repo = ref.read(youtubeSearchRepositoryProvider);
  final results = await repo.search(query);
  
  if (results.isNotEmpty) {
    Future.microtask(() {
      if (!ref.mounted) return;
      final items = results.map((e) => MediaItem(
        id: e.id,
        title: e.title,
        artist: e.author,
        album: e.album,
        thumbnailUrl: e.thumbnailUrl,
        path: e.id,
        type: 'audio',
      )).toList();
      ref.read(audioProvider.notifier).preloadTracks(items);
    });
  }
  
  return results;
});

final searchPlaylistResultsProvider = FutureProvider<List<ExplorePlaylist>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];

  final repo = ref.read(youtubeSearchRepositoryProvider);
  return repo.searchPlaylists(query);
});

class ExploreSearchTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final exploreSearchTabProvider = NotifierProvider<ExploreSearchTabNotifier, int>(ExploreSearchTabNotifier.new);

final featuredMusicProvider = FutureProvider<List<ExploreItem>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  final repo = ref.read(youtubeSearchRepositoryProvider);
  final results = await repo.getFeaturedMusic();
  
  if (results.isNotEmpty) {
    Future.microtask(() {
      final items = results.map((e) => MediaItem(
        id: e.id,
        title: e.title,
        artist: e.author,
        thumbnailUrl: e.thumbnailUrl,
        path: e.id,
        type: 'audio',
      )).toList();
      ref.read(audioProvider.notifier).preloadTracks(items);
    });
  }
  
  return results;
});

// ── Personalized Taste & Recommendation Providers ──────────────────────────

final quickPicksProvider = FutureProvider<List<MediaItem>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  return ref.read(tasteProfileServiceProvider).buildQuickPicks();
});

final dailyDiscoverProvider = FutureProvider<List<MediaItem>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  return ref.read(tasteProfileServiceProvider).buildDailyDiscover();
});

final forgottenFavoritesProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.read(tasteProfileServiceProvider).getForgottenFavorites();
});

final similarArtistsProvider = FutureProvider<List<({String artist, List<MediaItem> tracks})>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  final taste = ref.read(tasteProfileServiceProvider);
  final topArtists = await taste.getTopArtistsWithSeeds(limit: 3);
  final repo = ref.read(youtubeSearchRepositoryProvider);

  final results = <({String artist, List<MediaItem> tracks})>[];
  for (final entry in topArtists) {
    try {
      final searchItems = await repo.search('${entry.artist} music');
      if (searchItems.isNotEmpty) {
        final tracks = searchItems
            .take(8)
            .map((e) => MediaItem(
                  id: e.id,
                  path: e.id,
                  title: e.title,
                  artist: e.author,
                  thumbnailUrl: e.thumbnailUrl,
                  type: 'audio',
                ))
            .toList();
        if (tracks.isNotEmpty) {
          results.add((artist: entry.artist, tracks: tracks));
        }
      }
    } catch (_) {}
  }
  return results;
});

final speedDialProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.read(tasteProfileServiceProvider).getSpeedDialItems();
});

