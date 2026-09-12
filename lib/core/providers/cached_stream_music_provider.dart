import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/data/services/cache_manager.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/core/domain/models/media_item.dart';

/// Scans `stream/audio/*.m4a` files and pairs each with its sidecar metadata
/// JSON to build a `List<MediaItem>` of all cached stream songs.
///
/// Used as offline fallback data source across Home, Explore, Queue, and
/// Playlist subsystems.
final cachedStreamMusicProvider = FutureProvider<List<MediaItem>>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  // Watching mediaCacheServiceProvider to re-evaluate if the service reloads
  ref.watch(mediaCacheServiceProvider);

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

      MediaItem? meta;
      try {
        final metaFile = File(p.join(metaDir.path, '$safeId.json'));
        if (metaFile.existsSync()) {
          final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          meta = MediaItem.fromJson(json);
        }
      } catch (_) {}

      if (meta != null) {
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
        // Metadata missing — create minimal placeholder from filename
        results.add(MediaItem(
          id: safeId,
          path: file.path,
          title: safeId,
          type: 'audio',
        ));
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
