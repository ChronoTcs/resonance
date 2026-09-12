import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import 'package:resonance/features/explore/data/models/explore_home.dart';
import 'package:resonance/features/explore/data/repositories/youtube_search_repository.dart';
import 'package:resonance/features/explore/application/services/taste_profile_service.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';

/// Online recommendation feeds from YouTube Music (Mixed for you, Listen again, Trending, Charts)
final homeFeedProvider = FutureProvider<List<ExploreHomeSection>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);
  final repo = ref.read(youtubeSearchRepositoryProvider);
  final sections = await repo.getHomeFeed();
  return sections
      .map((section) {
        return ExploreHomeSection(
          title: section.title,
          items: section.items
              .where((item) => item.isPlaylist || !blockedNotifier.isBlocked(item.id))
              .toList(),
        );
      })
      .where((section) => section.items.isNotEmpty)
      .toList();
});

/// Personalized Quick Picks 4-row snap carousel (seeding by recent tastes)
/// Offline: falls back to cached stream music tracks
final quickPicksProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);
  final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));

  if (!isOnline) {
    final cached = await ref.watch(cachedStreamMusicProvider.future);
    return cached
        .where((t) => !blockedNotifier.isBlocked(t.id, path: t.path))
        .take(20)
        .toList();
  }

  try {
    await ref.read(recentlyPlayedProvider.future);
  } catch (_) {}
  final raw = await ref.read(tasteProfileServiceProvider).buildQuickPicks();
  return raw.where((t) => !blockedNotifier.isBlocked(t.id, path: t.path)).toList();
});

/// Daily Discover mix seeded by user listening trends
/// Offline: falls back to cached stream music (shuffled)
final dailyDiscoverProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);
  final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));

  if (!isOnline) {
    final cached = await ref.watch(cachedStreamMusicProvider.future);
    final items = cached
        .where((t) => !blockedNotifier.isBlocked(t.id, path: t.path))
        .toList()
      ..shuffle();
    return items.take(20).toList();
  }

  try {
    await ref.read(recentlyPlayedProvider.future);
  } catch (_) {}
  final raw = await ref.read(tasteProfileServiceProvider).buildDailyDiscover();
  return raw.where((t) => !blockedNotifier.isBlocked(t.id, path: t.path)).toList();
});

/// Forgotten Favorites mix (tracks user hasn't played in a while)
final forgottenFavoritesProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);
  try {
    await ref.read(recentlyPlayedProvider.future);
  } catch (_) {}
  final raw = await ref.read(tasteProfileServiceProvider).getForgottenFavorites();
  return raw.where((t) => !blockedNotifier.isBlocked(t.id, path: t.path)).toList();
});

/// Similar to [Artist] dynamic radios
final similarArtistsProvider =
    FutureProvider<List<({String artist, List<MediaItem> tracks})>>((ref) async {
  if (!ref.watch(networkConnectivityProvider.select((s) => s.isOnline))) return [];
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);
  try {
    await ref.read(recentlyPlayedProvider.future);
  } catch (_) {}
  final taste = ref.read(tasteProfileServiceProvider);
  final topArtists = await taste.getTopArtistsWithSeeds(limit: 3);
  final repo = ref.read(youtubeSearchRepositoryProvider);

  final results = <({String artist, List<MediaItem> tracks})>[];
  for (final entry in topArtists) {
    try {
      final searchItems = await repo.search('${entry.artist} music');
      if (searchItems.isNotEmpty) {
        final tracks = searchItems
            .map((e) => MediaItem(
                  id: e.id,
                  path: e.id,
                  title: e.title,
                  artist: e.author,
                  thumbnailUrl: e.thumbnailUrl,
                  type: 'audio',
                ))
            .where((t) => !blockedNotifier.isBlocked(t.id, path: t.path))
            .take(8)
            .toList();
        if (tracks.isNotEmpty) {
          results.add((artist: entry.artist, tracks: tracks));
        }
      }
    } catch (_) {}
  }
  return results;
});

/// Speed Dial 2-row bento grid items
final speedDialProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);
  final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));

  try {
    await ref.read(recentlyPlayedProvider.future);
  } catch (_) {}
  final raw = await ref.read(tasteProfileServiceProvider).getSpeedDialItems();
  final unblocked = raw.where((t) => !blockedNotifier.isBlocked(t.id, path: t.path)).toList();

  if (!isOnline) {
    final cached = await ref.watch(cachedStreamMusicProvider.future);
    final cachedIds = cached.map((t) => t.id ?? t.path).toSet();

    final offlinePlayable = unblocked.where((t) {
      final isLocal = !t.isStreaming ||
          (t.path.isNotEmpty &&
              !t.path.startsWith('http') &&
              (t.path.contains('/') || t.path.contains('\\')));
      return isLocal || cachedIds.contains(t.id ?? t.path);
    }).toList();

    if (offlinePlayable.length < 6) {
      final seenIds = offlinePlayable.map((t) => t.id ?? t.path).toSet();
      for (final song in cached) {
        final id = song.id ?? song.path;
        if (!seenIds.contains(id) && !blockedNotifier.isBlocked(song.id, path: song.path)) {
          offlinePlayable.add(song);
          seenIds.add(id);
          if (offlinePlayable.length >= 8) break;
        }
      }
    }
    return offlinePlayable;
  }

  return unblocked;
});
