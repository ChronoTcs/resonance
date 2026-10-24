import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

final userTasteProfileServiceProvider = Provider<UserTasteProfileService>((ref) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return UserTasteProfileService(cacheManager);
});

/// Metrics for a single track's engagement history.
class ProfileTrackEngagement {
  final String id;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int playCount;
  final int skipCount;
  final double completionSum; // Sum of completion ratios (0.0 to 1.0)
  final DateTime lastPlayed;
  final bool isUserInitiated;

  ProfileTrackEngagement({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.playCount,
    required this.skipCount,
    required this.completionSum,
    required this.lastPlayed,
    required this.isUserInitiated,
  });

  double get averageCompletion =>
      playCount > 0 ? (completionSum / playCount).clamp(0.0, 1.0) : 0.0;

  bool get isCoreAnchor => playCount >= 2 && averageCompletion >= 0.6;
  bool get isNegativeSignal => skipCount >= 2 && playCount == 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'playCount': playCount,
        'skipCount': skipCount,
        'completionSum': completionSum,
        'lastPlayed': lastPlayed.toIso8601String(),
        'isUserInitiated': isUserInitiated,
      };

  factory ProfileTrackEngagement.fromJson(Map<String, dynamic> json) =>
      ProfileTrackEngagement(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        playCount: (json['playCount'] as num?)?.toInt() ?? 0,
        skipCount: (json['skipCount'] as num?)?.toInt() ?? 0,
        completionSum: (json['completionSum'] as num?)?.toDouble() ?? 0.0,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.tryParse(json['lastPlayed'] as String) ?? DateTime.now()
            : DateTime.now(),
        isUserInitiated: json['isUserInitiated'] as bool? ?? true,
      );
}

/// Service managing persistent user taste profiling, artist affinities,
/// and core anchor tracks in `user_taste_profile.json`.
class UserTasteProfileService {
  final CacheManager _cacheManager;
  final String _fileName = 'user_taste_profile.json';

  final Map<String, ProfileTrackEngagement> _engagements = {};
  final Map<String, double> _artistAffinities = {};
  bool _isLoaded = false;

  UserTasteProfileService(this._cacheManager);

  Future<File> get _file async {
    final metaDir = await _cacheManager.getBaseCacheDir();
    return File(p.join(metaDir.path, _fileName));
  }

  /// Loads profile from local disk cache into memory.
  Future<void> loadFromDisk() async {
    if (_isLoaded) return;
    try {
      final file = await _file;
      if (!await file.exists()) {
        _isLoaded = true;
        return;
      }
      final raw = await file.readAsString();
      if (raw.isEmpty) {
        _isLoaded = true;
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      
      _engagements.clear();
      final tracks = data['tracks'] as Map<String, dynamic>? ?? {};
      tracks.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          _engagements[k] = ProfileTrackEngagement.fromJson(v);
        }
      });

      _artistAffinities.clear();
      final artists = data['artistAffinities'] as Map<String, dynamic>? ?? {};
      artists.forEach((k, v) {
        if (v is num) {
          _artistAffinities[k] = v.toDouble();
        }
      });

      _isLoaded = true;
      debugPrint('[UserTasteProfile] Loaded ${_engagements.length} tracks, ${_artistAffinities.length} artists');
    } catch (e) {
      debugPrint('[UserTasteProfile] loadFromDisk error: $e');
      _isLoaded = true;
    }
  }

  /// Records engagement signals when a track finishes or skips.
  Future<void> recordEngagement(
    MediaItem track, {
    Duration? position,
    Duration? duration,
    bool isUserInitiated = true,
  }) async {
    await loadFromDisk();
    final songId = track.id ?? track.path;
    if (songId.isEmpty) return;

    final posSec = position?.inSeconds ?? 0;
    final durSec = duration?.inSeconds ?? track.duration?.inSeconds ?? 0;
    final completionRatio = durSec > 0 ? (posSec / durSec).clamp(0.0, 1.0) : 0.0;
    final isQuickSkip = posSec < 20 && completionRatio < 0.25;
    final isCompletedPlay = completionRatio >= 0.65;

    final existing = _engagements[songId];
    final currentPlayCount = (existing?.playCount ?? 0) + (isCompletedPlay ? 1 : 0);
    final currentSkipCount = (existing?.skipCount ?? 0) + (isQuickSkip ? 1 : 0);
    final currentCompletionSum = (existing?.completionSum ?? 0.0) + completionRatio;

    _engagements[songId] = ProfileTrackEngagement(
      id: songId,
      title: track.title,
      artist: track.artist ?? 'Unknown Artist',
      thumbnailUrl: track.thumbnailUrl,
      playCount: currentPlayCount,
      skipCount: currentSkipCount,
      completionSum: currentCompletionSum,
      lastPlayed: DateTime.now(),
      isUserInitiated: isUserInitiated || (existing?.isUserInitiated ?? false),
    );

    // Update Artist Affinity Matrix
    final artistName = (track.artist ?? '').trim();
    if (artistName.isNotEmpty && artistName.toLowerCase() != 'unknown artist') {
      final currentScore = _artistAffinities[artistName] ?? 0.0;
      if (isCompletedPlay) {
        final gain = (log(currentPlayCount + 1) / ln2) * completionRatio;
        _artistAffinities[artistName] = (currentScore + gain).clamp(0.0, 100.0);
      } else if (isQuickSkip) {
        _artistAffinities[artistName] = (currentScore - 0.5).clamp(0.0, 100.0);
      }
    }

    await _syncToDisk();
  }

  /// Returns core anchor tracks with high repeat count and high completion.
  Future<List<MediaItem>> getCoreAnchorSeeds({int limit = 5}) async {
    await loadFromDisk();
    final candidates = _engagements.values
        .where((t) => t.isCoreAnchor)
        .toList()
      ..sort((a, b) {
        final scoreA = a.playCount * a.averageCompletion;
        final scoreB = b.playCount * b.averageCompletion;
        return scoreB.compareTo(scoreA);
      });

    return candidates.take(limit).map((e) => MediaItem(
      id: e.id,
      path: e.id,
      title: e.title,
      artist: e.artist,
      thumbnailUrl: e.thumbnailUrl,
      type: 'audio',
    )).toList();
  }

  /// Returns top affinity artist names sorted by cumulative engagement score.
  Future<List<String>> getTopAffinityArtists({int limit = 5}) async {
    await loadFromDisk();
    final entries = _artistAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  /// Checks if a track ID has negative skip signals (penalized).
  bool isNegativeSignal(String? id) {
    if (id == null) return false;
    final engagement = _engagements[id];
    return engagement?.isNegativeSignal ?? false;
  }

  Future<void> _syncToDisk() async {
    try {
      final file = await _file;
      final payload = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'tracks': _engagements.map((k, v) => MapEntry(k, v.toJson())),
        'artistAffinities': _artistAffinities,
      };
      await _cacheManager.synchronizedWrite(file, jsonEncode(payload));
    } catch (e) {
      debugPrint('[UserTasteProfile] _syncToDisk error: $e');
    }
  }
}
