import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';

final Set<String> _healingTrackIds = {};

void _triggerAutoHeal(Ref ref, String songId) {
  if (_healingTrackIds.contains(songId)) return;
  if (ref.read(blockedTracksProvider.notifier).isBlocked(songId)) return;
  final isOnline = ref.read(networkConnectivityProvider).isOnline;
  if (!isOnline) return;

  final cacheService = ref.read(mediaCacheServiceProvider);

  _healingTrackIds.add(songId);

  Future.microtask(() async {
    yt.YoutubeExplode? ytClient;
    try {
      ytClient = yt.YoutubeExplode();
      final video = await ytClient.videos.get(songId);

      final thumb = video.thumbnails.maxResUrl.isNotEmpty
          ? video.thumbnails.maxResUrl
          : (video.thumbnails.highResUrl.isNotEmpty
              ? video.thumbnails.highResUrl
              : video.thumbnails.mediumResUrl);

      final healed = MediaItem(
        id: songId,
        path: songId,
        title: video.title,
        artist: video.author.isNotEmpty ? video.author : 'Unknown Artist',
        thumbnailUrl: thumb,
        duration: video.duration,
        type: 'audio',
      );

      await cacheService.saveMetadata(songId, healed);

      if (thumb.isNotEmpty) {
        unawaited(cacheService.cacheArtwork(songId, thumb));
      }
      debugPrint('[CachedStreamAutoHeal] Healed orphan metadata for $songId (${video.title})');
      try {
        ref.invalidateSelf();
      } catch (_) {}
    } on yt.VideoUnavailableException catch (e) {
      debugPrint('[CachedStreamAutoHeal] Video $songId unavailable on YouTube — purging dead orphan audio from cache: $e');
      try {
        await cacheService.removeFromCache(songId);
      } catch (_) {}
    } catch (e) {
      debugPrint('[CachedStreamAutoHeal] Failed to heal metadata for $songId: $e');
    } finally {
      ytClient?.close();
      _healingTrackIds.remove(songId);
    }
  });
}

/// Scans `stream/audio/*.m4a` files and pairs each with its sidecar metadata
/// JSON to build a `List<MediaItem>` of all cached stream songs.
///
/// Used as offline fallback data source across Home, Explore, Queue, and
/// Playlist subsystems.
final cachedStreamMusicProvider = FutureProvider<List<MediaItem>>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  ref.watch(blockedTracksProvider);
  final blockedNotifier = ref.read(blockedTracksProvider.notifier);

  try {
    final audioDir = await cacheManager.getStreamAudioDir();
    if (!audioDir.existsSync()) return [];

    final m4aFiles = audioDir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList();

    if (m4aFiles.isEmpty) return [];

    final metaDir = await cacheManager.getMetadataDir();
    final imagesDir = await cacheManager.getStreamImagesDir();

    final List<MediaItem> results = [];
    for (final file in m4aFiles) {
      final safeId = p.basenameWithoutExtension(file.path);

      // Guard: skip blocked tracks completely
      if (blockedNotifier.isBlocked(safeId, path: file.path)) continue;

      MediaItem? meta;
      try {
        final metaFile = File(p.join(metaDir.path, '$safeId.json'));
        if (metaFile.existsSync()) {
          final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          meta = MediaItem.fromJson(json);
        }
      } catch (_) {}

      if (meta != null) {
        if (blockedNotifier.isBlocked(meta.id, path: meta.path)) continue;

        // Resolve local art path
        String? localArtPath;
        for (final ext in ['.jpg', '.webp', '.png']) {
          final artFile = File(p.join(imagesDir.path, 'art_$safeId$ext'));
          if (artFile.existsSync()) {
            localArtPath = artFile.path;
            break;
          }
        }
        final resolved = meta.copyWith(
          path: file.path,
          thumbnailUrl: localArtPath ?? meta.thumbnailUrl,
        );
        results.add(resolved);
      } else {
        // Metadata missing — trigger background healing
        _triggerAutoHeal(ref, safeId);
        // Do NOT surface raw video ID placeholder cards to UI feeds
      }
    }

    return results;
  } catch (_) {
    return [];
  }
});

/// Combined offline-playable pool: local scanned files + cached stream music.
/// Used by `QueueOrchestrator` and any component needing "what can I play offline?".
final playableOfflineTracksProvider = FutureProvider<List<MediaItem>>((ref) async {
  final cached = await ref.watch(cachedStreamMusicProvider.future);
  return cached;
});
