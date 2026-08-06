import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/data/services/cache_manager.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../library/data/models/media_item.dart';

class LyricsLocalDataSource {
  final Ref _ref;

  LyricsLocalDataSource(this._ref);

  /// Checks and returns standard LRC file content from a custom lyric folder
  Future<String?> getFromCustomFolder(MediaItem track, String lyricsFolderPath) async {
    final String trackPath = track.path;
    final safeId = (track.id != null && track.id!.isNotEmpty)
        ? track.id!.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        : '';

    if (safeId.isNotEmpty) {
      final idLrcPath = p.join(lyricsFolderPath, '$safeId.lrc');
      final idFile = File(idLrcPath);
      if (await idFile.exists()) {
        return await idFile.readAsString();
      }
    }

    final String fileName = (track.title.isNotEmpty && track.title != 'Unknown')
        ? track.title
        : p.basenameWithoutExtension(trackPath);

    final lrcPath = p.join(lyricsFolderPath, '$fileName.lrc');
    final file = File(lrcPath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  /// Checks and returns LRC file located in the same directory as the local audio track
  Future<String?> getFromLocalTrackFolder(MediaItem track) async {
    if (track.isStreaming) return null;
    final trackPath = track.path;
    if (trackPath.contains('.')) {
      final lrcPath = '${trackPath.substring(0, trackPath.lastIndexOf('.'))}.lrc';
      final file = File(lrcPath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }
    return null;
  }

  /// Checks and returns lyrics cached inside our internal stream cache folder
  Future<({String content, File cachedFile})?> getFromCache(MediaItem track) async {
    final cacheDir = await _ref.read(cacheManagerProvider).getStreamLyricsDir();
    final songId = track.id ?? track.path;
    final saveId = _ref.read(mediaCacheServiceProvider).getSafeFilename(songId);
    final File cachedFile = File(p.join(cacheDir.path, '$saveId.lrc'));

    if (await cachedFile.exists()) {
      final content = await cachedFile.readAsString();
      return (content: content, cachedFile: cachedFile);
    }
    return null;
  }

  /// Writes downloaded lyrics to local cache
  Future<void> saveToCache(MediaItem track, String content) async {
    final cacheDir = await _ref.read(cacheManagerProvider).getStreamLyricsDir();
    final songId = track.id ?? track.path;
    final saveId = _ref.read(mediaCacheServiceProvider).getSafeFilename(songId);
    final File cachedFile = File(p.join(cacheDir.path, '$saveId.lrc'));
    try {
      await cachedFile.writeAsString(content);
    } catch (_) {}
  }
}

final lyricsLocalDataSourceProvider = Provider<LyricsLocalDataSource>((ref) {
  return LyricsLocalDataSource(ref);
});
