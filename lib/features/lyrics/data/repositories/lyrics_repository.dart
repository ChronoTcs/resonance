import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../../../library/data/models/media_item.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/data_usage_service.dart';

class LyricsRepository {
  final Ref _ref;

  LyricsRepository(this._ref);

  Future<List<LyricLine>> getLyrics(
    MediaItem track, {
    String? lyricsFolderPath,
  }) async {
    final String trackPath = track.path;
    final cacheService = _ref.read(mediaCacheServiceProvider);

    // Determine Identity
    final String songId = track.id ?? trackPath;
    final bool isStreaming = trackPath.startsWith('http') || (track.id != null && !track.id!.startsWith('loc_'));

    // Determine filename for cache (safe version of ID)
    final String safeCacheId = isStreaming
        ? songId
        : p.basenameWithoutExtension(trackPath);

    // Recover metadata for cached tracks only if critical info is missing
    MediaItem currentTrack = track;
    bool needsMetadata =
        track.artist == null ||
        track.artist!.isEmpty ||
        track.artist == 'Unknown Artist' ||
        track.title == songId ||
        songId.startsWith('loc_');

    if (needsMetadata) {
      final cachedMeta = await cacheService.getCachedMetadata(songId);
      if (cachedMeta != null) {
        currentTrack = cachedMeta;
      }
    }

    // 1. Check Custom Lyrics Folder
    if (lyricsFolderPath != null) {
      // 1a. UNIFIED ID: Prefer [id].lrc (Fastest & Accurate)
      final String safeId = (track.id != null && track.id!.isNotEmpty)
          ? track.id!.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          : '';

      if (safeId.isNotEmpty) {
        final idLrcPath = p.join(lyricsFolderPath, '$safeId.lrc');
        final idFile = File(idLrcPath);
        if (await idFile.exists()) {
          final content = await idFile.readAsString();
          return _parseLrc(content);
        }
      }

      // 1b. LEGACY FALLBACK: Title.lrc
      final String fileName = (currentTrack.title.isNotEmpty && currentTrack.title != 'Unknown')
          ? currentTrack.title
          : p.basenameWithoutExtension(trackPath);
      
      final lrcPath = p.join(lyricsFolderPath, '$fileName.lrc');
      final file = File(lrcPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return _parseLrc(content);
      }
    }

    // 2. Check Local Folder (Same directory as track)
    if (!isStreaming) {
      if (trackPath.contains('.')) {
        final lrcPath =
            trackPath.substring(0, trackPath.lastIndexOf('.')) + '.lrc';
        final file = File(lrcPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          return _parseLrc(content);
        }
      }
    }

    // 3. Check Cache
    final cacheDir = await _ref.read(cacheManagerProvider).getStreamLyricsDir();
    final safeId = cacheService.getSafeFilename(safeCacheId);
    final cachedFile = File(p.join(cacheDir.path, '$safeId.lrc'));
    if (await cachedFile.exists()) {
      final content = await cachedFile.readAsString();
      return _parseLrc(content);
    }

    // 4. Fetch from LRCLIB
    if (isStreaming &&
        currentTrack.title.isNotEmpty &&
        currentTrack.title != songId) {
      final artist = (currentTrack.artist ?? '').replaceAll(
        RegExp(r' - Topic$'),
        '',
      );
      final title = currentTrack.title;

      final uri = Uri.parse('https://lrclib.net/api/get').replace(
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
          if (currentTrack.duration != null &&
              currentTrack.duration!.inSeconds > 0)
            'duration': currentTrack.duration!.inSeconds.toString(),
        },
      );

      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          _ref
              .read(dataUsageServiceProvider)
              .addBytes(response.bodyBytes.length);

          final data = jsonDecode(response.body);
          final lyrics =
              (data['syncedLyrics'] as String?) ??
              (data['plainLyrics'] as String?);

          if (lyrics != null && lyrics.isNotEmpty) {
            await cachedFile.writeAsString(lyrics);
            return _parseLrc(lyrics);
          }
        }
      } catch (e) {
        print('LRCLIB fetch error: $e');
      }
    }

    return [];
  }

  List<LyricLine> _parseLrc(String content) {
    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];
    final timeTagRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lines) {
      final match = timeTagRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        String millisStr = match.group(3)!;
        if (millisStr.length == 2) millisStr += '0';
        final milliseconds = int.parse(millisStr);

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        final text = line.substring(match.end).trim();
        parsedLines.add(LyricLine(timestamp: duration, text: text));
      }
    }

    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return parsedLines;
  }
}

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  return LyricsRepository(ref);
});
