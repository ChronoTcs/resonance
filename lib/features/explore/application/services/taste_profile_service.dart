import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/core/data/services/stream_cache_tracker_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_search_repository.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

final tasteProfileServiceProvider = Provider<TasteProfileService>((ref) {
  return TasteProfileService(ref);
});

/// Local personalization & taste recommendation engine.
/// Calculates Quick Picks, Daily Discover, Forgotten Favorites, Similar Artists,
/// and Speed Dial grids using local history & play counts.
class TasteProfileService {
  final Ref _ref;

  TasteProfileService(this._ref);

  /// Seeds derived from recent history + top play counts
  Future<List<MediaItem>> getQuickPickSeeds({int limit = 5}) async {
    final recentItems = _ref.read(recentlyPlayedProvider).value ?? [];
    final validRecent = recentItems.where((i) => (i.id ?? '').isNotEmpty).toList();
    if (validRecent.isNotEmpty) {
      return validRecent.take(limit).toList();
    }
    return [];
  }

  /// Resolves any [seed] (local or online) to a valid 11-char YouTube video ID for InnerTube radio.
  /// If [seed] is local or lacks a valid YouTube ID, searches YouTube Music for "${artist} ${title}".
  Future<String?> _resolveToOnlineSeedId(MediaItem seed) async {
    final rawId = (seed.id ?? seed.path).trim();
    final isYtId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(rawId);
    if (!seed.isLocal && isYtId) {
      return rawId;
    }

    // Search YouTube Music using Title & Artist
    final artistStr = seed.artist;
    final query = '${artistStr != null && artistStr != 'Unknown Artist' ? artistStr : ''} ${seed.title}'.trim();
    if (query.isEmpty) return null;

    try {
      final searchRepo = _ref.read(youtubeSearchRepositoryProvider);
      final results = await searchRepo.search(query);
      if (results.isNotEmpty) {
        final matchId = results.first.id;
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(matchId)) {
          return matchId;
        }
      }
    } catch (e) {
      debugPrint('[TasteProfileService] Failed resolving online seed for "$query": $e');
    }
    return null;
  }

  /// Builds a personalized Quick Picks queue based on user's top seeds
  Future<List<MediaItem>> buildQuickPicks({int limit = 20}) async {
    final seeds = await getQuickPickSeeds(limit: 5);
    final repo = _ref.read(youtubeSearchRepositoryProvider);
    final results = <MediaItem>[];
    final seenIds = <String>{};

    for (final seed in seeds) {
      final localId = seed.id ?? seed.path;
      seenIds.add(localId);
    }

    if (seeds.isNotEmpty) {
      for (final seed in seeds) {
        try {
          final onlineSeedId = await _resolveToOnlineSeedId(seed);
          if (onlineSeedId != null) {
            seenIds.add(onlineSeedId);
            final recs = await repo.getRadioRecommendations(onlineSeedId, limit: 10);
            for (final track in recs) {
              final id = track.id ?? track.path;
              if (!seenIds.contains(id)) {
                seenIds.add(id);
                results.add(track);
              }
              if (results.length >= limit) break;
            }
          } else {
            // Fallback: search for "${artist} music" or "${title}"
            final query = '${seed.artist ?? seed.title} music'.trim();
            final searchItems = await repo.search(query);
            for (final item in searchItems) {
              if (!seenIds.contains(item.id)) {
                seenIds.add(item.id);
                results.add(MediaItem(
                  id: item.id,
                  path: item.id,
                  title: item.title,
                  artist: item.author,
                  thumbnailUrl: item.thumbnailUrl,
                  type: 'audio',
                ));
              }
              if (results.length >= limit) break;
            }
          }
        } catch (e) {
          debugPrint('[TasteProfileService] Quick Picks error for seed ${seed.title}: $e');
        }
        if (results.length >= limit) break;
      }
    }

    // Fallback 1: If results < 16, pull stream tracks from homeFeedProvider
    if (results.length < 16) {
      try {
        final homeSections = _ref.read(homeFeedProvider).value ?? [];
        for (final sec in homeSections) {
          for (final it in sec.items) {
            if (!it.isPlaylist && !seenIds.contains(it.id)) {
              seenIds.add(it.id);
              results.add(MediaItem(
                id: it.id,
                path: it.id,
                title: it.title,
                artist: it.subtitle,
                thumbnailUrl: it.thumbnailUrl,
                type: 'audio',
              ));
            }
            if (results.length >= limit) break;
          }
          if (results.length >= limit) break;
        }
      } catch (_) {}
    }

    // Fallback 2: If results < 16, search popular hits
    if (results.length < 16) {
      try {
        final trending = await repo.search('popular music hits');
        for (final item in trending) {
          if (!seenIds.contains(item.id)) {
            seenIds.add(item.id);
            results.add(MediaItem(
              id: item.id,
              path: item.id,
              title: item.title,
              artist: item.author,
              thumbnailUrl: item.thumbnailUrl,
              type: 'audio',
            ));
          }
          if (results.length >= limit) break;
        }
      } catch (_) {}
    }

    // Fallback 3: Local audio library
    if (results.length < 16) {
      final localAudios = _ref.read(libraryProvider).allMedia.where((m) => m.type == 'audio');
      for (final local in localAudios) {
        final id = local.id ?? local.path;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          results.add(local);
        }
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  /// Builds a Daily Discover mix from user top history
  Future<List<MediaItem>> buildDailyDiscover({int limit = 20}) async {
    final tracker = _ref.read(streamCacheTrackerServiceProvider);
    final topIds = await tracker.getTopPlayedIds(limit: 3);
    final recentItems = _ref.read(recentlyPlayedProvider).value ?? [];
    
    final repo = _ref.read(youtubeSearchRepositoryProvider);
    final results = <MediaItem>[];
    final seenIds = <String>{};

    // 1. If top tracker IDs exist, use them directly
    if (topIds.isNotEmpty) {
      for (final seedId in topIds) {
        seenIds.add(seedId);
        try {
          final recs = await repo.getRadioRecommendations(seedId, limit: 10);
          for (final track in recs) {
            final id = track.id ?? track.path;
            if (!seenIds.contains(id)) {
              seenIds.add(id);
              results.add(track);
            }
            if (results.length >= limit) break;
          }
        } catch (e) {
          debugPrint('[TasteProfileService] Daily Discover error for seed $seedId: $e');
        }
        if (results.length >= limit) break;
      }
    }

    // 2. If still need items or no topIds, use recent seeds (resolving local items to online IDs)
    if (results.length < limit && recentItems.isNotEmpty) {
      for (final seed in recentItems.take(5)) {
        if (results.length >= limit) break;
        try {
          final onlineSeedId = await _resolveToOnlineSeedId(seed);
          if (onlineSeedId != null && !seenIds.contains(onlineSeedId)) {
            seenIds.add(onlineSeedId);
            final recs = await repo.getRadioRecommendations(onlineSeedId, limit: 8);
            for (final track in recs) {
              final id = track.id ?? track.path;
              if (!seenIds.contains(id)) {
                seenIds.add(id);
                results.add(track);
              }
              if (results.length >= limit) break;
            }
          }
        } catch (e) {
          debugPrint('[TasteProfileService] Daily Discover error for recent seed ${seed.title}: $e');
        }
      }
    }

    return results;
  }

  /// Surfaces tracks with high historical play counts not played recently (stream + local history blend)
  Future<List<MediaItem>> getForgottenFavorites({int limit = 10}) async {
    final tracker = _ref.read(streamCacheTrackerServiceProvider);
    final cache = _ref.read(mediaCacheServiceProvider);
    final recentItems = _ref.read(recentlyPlayedProvider).value ?? [];

    final results = <MediaItem>[];
    final seenKeys = <String>{};

    // 1. Items from stream cache tracker (played >= 2 times, inactive >= 14 days)
    final streamIds = await tracker.getForgottenFavoriteIds(
      minPlayCount: 2,
      inactiveThreshold: const Duration(days: 14),
      limit: limit,
    );

    for (final id in streamIds) {
      final meta = await cache.getCachedMetadata(id);
      if (meta != null) {
        final key = '${meta.title.toLowerCase()}_${meta.artist?.toLowerCase() ?? ""}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          results.add(meta);
        }
      }
    }

    // 2. Blend local history tracks played previously but not in the most recent 8 items
    if (results.length < limit && recentItems.length > 8) {
      final olderRecent = recentItems.skip(8);
      for (final item in olderRecent) {
        final key = '${item.title.toLowerCase()}_${item.artist?.toLowerCase() ?? ""}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          results.add(item);
        }
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  /// Extracts top listened artists from history paired with their seed track.
  /// Falls back to local library audio tracks or home feed if history is empty.
  Future<List<({String artist, MediaItem seed})>> getTopArtistsWithSeeds({int limit = 3}) async {
    final recentItems = _ref.read(recentlyPlayedProvider).value ?? [];
    final artistCounts = <String, int>{};
    final artistSeedMap = <String, MediaItem>{};

    for (final item in recentItems) {
      final artist = (item.artist ?? '').trim();
      if (artist.isEmpty || artist.toLowerCase() == 'unknown artist') continue;

      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      artistSeedMap.putIfAbsent(artist, () => item);
    }

    // Fallback 1: Local library audio tracks if history has no artists yet
    if (artistCounts.isEmpty) {
      final localAudios = _ref.read(libraryProvider).allMedia.where((m) => m.type == 'audio');
      for (final item in localAudios) {
        final artist = (item.artist ?? '').trim();
        if (artist.isEmpty || artist.toLowerCase() == 'unknown artist') continue;
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
        artistSeedMap.putIfAbsent(artist, () => item);
      }
    }

    // Fallback 2: Home feed sections if library is also empty
    if (artistCounts.isEmpty) {
      final homeSections = _ref.read(homeFeedProvider).value ?? [];
      for (final sec in homeSections) {
        for (final item in sec.items) {
          if (item.isPlaylist) continue;
          final artist = item.subtitle.trim();
          if (artist.isEmpty || artist.toLowerCase() == 'unknown artist') continue;
          artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
          artistSeedMap.putIfAbsent(
            artist,
            () => MediaItem(
              id: item.id,
              path: item.id,
              title: item.title,
              artist: item.subtitle,
              thumbnailUrl: item.thumbnailUrl,
              type: 'audio',
            ),
          );
        }
      }
    }

    if (artistCounts.isEmpty) return [];

    final sortedArtists = artistCounts.keys.toList()
      ..sort((a, b) => (artistCounts[b] ?? 0).compareTo(artistCounts[a] ?? 0));

    final result = <({String artist, MediaItem seed})>[];
    for (final artist in sortedArtists.take(limit)) {
      final seed = artistSeedMap[artist];
      if (seed != null) {
        result.add((artist: artist, seed: seed));
      }
    }
    return result;
  }

  /// Returns items for the Speed Dial quick access grid (recent + top played blend + recommendations)
  Future<List<MediaItem>> getSpeedDialItems({int limit = 18}) async {
    final recentItems = _ref.read(recentlyPlayedProvider).value ?? [];
    final cache = _ref.read(mediaCacheServiceProvider);
    final tracker = _ref.read(streamCacheTrackerServiceProvider);

    final result = <MediaItem>[];
    final seenIds = <String>{};

    // 1. Take up to 10 most recent
    for (final item in recentItems) {
      final id = item.id ?? item.path;
      if (id.isNotEmpty && !seenIds.contains(id)) {
        seenIds.add(id);
        result.add(item);
      }
      if (result.length >= 10) break;
    }

    // 2. Take top played
    final topIds = await tracker.getTopPlayedIds(limit: 8);
    for (final id in topIds) {
      if (!seenIds.contains(id)) {
        final meta = await cache.getCachedMetadata(id);
        if (meta != null) {
          seenIds.add(id);
          result.add(meta);
        }
      }
      if (result.length >= limit) break;
    }

    // 3. Fallback: If still under 16, pull stream tracks from homeFeedProvider
    if (result.length < 16) {
      final homeSections = _ref.read(homeFeedProvider).value ?? [];
      for (final sec in homeSections) {
        for (final it in sec.items) {
          if (!it.isPlaylist && !seenIds.contains(it.id)) {
            seenIds.add(it.id);
            result.add(MediaItem(
              id: it.id,
              path: it.id,
              title: it.title,
              artist: it.subtitle,
              thumbnailUrl: it.thumbnailUrl,
              type: 'audio',
            ));
          }
          if (result.length >= limit) break;
        }
        if (result.length >= limit) break;
      }
    }

    // 4. Fallback: If still under 16, pull from local library
    if (result.length < 16) {
      final localAudios = _ref.read(libraryProvider).allMedia.where((m) => m.type == 'audio');
      for (final local in localAudios) {
        final id = local.id ?? local.path;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          result.add(local);
        }
        if (result.length >= limit) break;
      }
    }

    return result;
  }
}
