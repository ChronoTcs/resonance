import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../../../library/data/models/media_item.dart';
import '../data_sources/lyrics_local_data_source.dart';
import '../data_sources/lyrics_remote_data_source.dart';
import '../services/lyrics_parser.dart';

class LyricsRepository {
  final Ref _ref;

  // Memory Cache for latest processed lyrics
  String? _lastTrackId;
  ({List<LyricLine> lines, bool isVideoSynced})? _lastLyrics;

  final Map<String, Future<({List<LyricLine> lines, bool isVideoSynced})>>
  _inFlightRequests = {};

  LyricsRepository(this._ref);

  Future<({List<LyricLine> lines, bool isVideoSynced})> getLyrics(
    MediaItem track, {
    String? lyricsFolderPath,
    bool forceSync = false,
  }) async {
    final trackId = track.id ?? track.path;

    // 1. Memory Cache Check
    if (_lastTrackId == trackId && _lastLyrics != null && !forceSync) {
      debugPrint(
        '[LyricsRepo][CACHE] Returning memory cached lyrics for $trackId',
      );
      return _lastLyrics!;
    }

    if (!forceSync && _inFlightRequests.containsKey(trackId)) {
      debugPrint(
        '[LyricsRepo][MUTEX] Joining existing in-flight request for $trackId',
      );
      return await _inFlightRequests[trackId]!;
    }

    final future = _fetchAndParseLyrics(track, lyricsFolderPath, forceSync);
    _inFlightRequests[trackId] = future;

    try {
      final result = await future;
      _lastTrackId = trackId;
      _lastLyrics = result;
      return result;
    } finally {
      _inFlightRequests.remove(trackId);
    }
  }

  Future<({List<LyricLine> lines, bool isVideoSynced})> _fetchAndParseLyrics(
    MediaItem track,
    String? lyricsFolderPath,
    bool forceSync,
  ) async {
    final localSource = _ref.read(lyricsLocalDataSourceProvider);
    final remoteSource = _ref.read(lyricsRemoteDataSourceProvider);

    // 1. Check Custom Lyrics Folder Override
    if (lyricsFolderPath != null) {
      final customContent = await localSource.getFromCustomFolder(
        track,
        lyricsFolderPath,
      );
      if (customContent != null) {
        debugPrint('[LyricsRepo] Found lyrics in Custom Folder Override');
        final isVideo = customContent.contains('[source: unison-video]');
        return (
          lines: LyricsParser.parse(customContent),
          isVideoSynced: isVideo,
        );
      }
    }

    // 2. Check Local File Folder (Same folder as audio file)
    final localFolderContent = await localSource.getFromLocalTrackFolder(track);
    if (localFolderContent != null) {
      debugPrint('[LyricsRepo] Found lyrics in Local Audio Directory');
      final isVideo = localFolderContent.contains('[source: unison-video]');
      return (
        lines: LyricsParser.parse(localFolderContent),
        isVideoSynced: isVideo,
      );
    }

    // 3. Check Stream Cache Folder
    final cachedRecord = await localSource.getFromCache(track);
    if (cachedRecord != null && !forceSync) {
      final cachedIsSynced = LyricsParser.hasTimeTags(cachedRecord.content);
      if (cachedIsSynced || !track.isStreaming) {
        debugPrint('[LyricsRepo] Found lyrics in Stream Cache Folder');
        final isVideo = cachedRecord.content.contains('[source: unison-video]');
        return (
          lines: LyricsParser.parse(cachedRecord.content),
          isVideoSynced: isVideo,
        );
      }
    }

    // 4. Remote Fetch Pipeline (Online fallback cascade)
    if (track.isStreaming && track.title.isNotEmpty) {
      String? foundContent;
      bool isUnisonVideo = false;

      // 4a. Unison API (First Priority - Word-Synced)
      debugPrint(
        '[LyricsRepo] Querying Unison API for word-synced lyrics...',
      );

      // Try video ID first (video-synced)
      final videoId = track.id ?? track.path;
      if (videoId.isNotEmpty) {
        foundContent = await remoteSource.fetchFromUnison(track);
        if (foundContent != null) {
          isUnisonVideo = true; // Video ID matched
        }
      }

      // Verify duration match for Unison
      if (foundContent != null) {
        final parsedLyrics = LyricsParser.parse(foundContent);
        if (!_verifyDurationMatch(parsedLyrics, track.duration)) {
          debugPrint(
            '[LyricsRepo] Discarding Unison lyrics due to duration mismatch.',
          );
          foundContent = null;
          isUnisonVideo = false;
        } else {
          debugPrint(
            '[LyricsRepo] Successfully matched and fetched Unison lyrics',
          );
        }
      }

      // 4b. LRCLIB API (Second Priority - Line-Synced)
      if (foundContent == null) {
        debugPrint(
          '[LyricsRepo] Querying LRCLIB API for line-synced lyrics...',
        );
        final durationSecs = track.duration?.inSeconds ?? 0;
        final parsed = LyricsParser.parseHyphenatedTitle(
          track.title,
          track.artist ?? '',
        );

        if (parsed.artist.isNotEmpty) {
          if (durationSecs > 0) {
            foundContent = await remoteSource.fetchFromLrcLibGet({
              'track_name': parsed.title,
              'artist_name': parsed.artist,
              'duration': durationSecs.toString(),
            });
          }
          foundContent ??= await remoteSource.fetchFromLrcLibGet({
            'track_name': parsed.title,
            'artist_name': parsed.artist,
          });
        }

        // Search Fallback query
        if (foundContent == null) {
          final queryArtist = parsed.artist.isNotEmpty
              ? parsed.artist
              : LyricsParser.cleanArtist(track.artist ?? '');
          final queryTitle = parsed.artist.isNotEmpty
              ? parsed.title
              : LyricsParser.cleanTitle(track.title);
          final query = queryArtist.isNotEmpty
              ? '$queryTitle $queryArtist'
              : queryTitle;
          foundContent = await remoteSource.fetchFromLrcLibSearch({'q': query});
        }

        if (foundContent != null) {
          debugPrint('[LyricsRepo] Successfully fetched LRCLIB lyrics');
        }
      }

      // 4c. Musixmatch API Bypass (Third Priority - Fallback Synced)
      if (foundContent == null) {
        debugPrint('[LyricsRepo] Querying Musixmatch API fallback...');
        final parsed = LyricsParser.parseHyphenatedTitle(
          track.title,
          track.artist ?? '',
        );
        foundContent = await remoteSource.fetchFromMusixmatch(
          parsed.title,
          parsed.artist,
        );
        if (foundContent != null) {
          debugPrint(
            '[LyricsRepo] Successfully fetched Musixmatch lyrics',
          );
        }
      }

      // 4d. Genius API Bypass (Fourth Priority - Plain Text Fallback)
      if (foundContent == null) {
        debugPrint(
          '[LyricsRepo] Querying Genius API plain text fallback...',
        );
        final query = track.artist != null
            ? '${track.title} ${track.artist}'
            : track.title;
        foundContent = await remoteSource.fetchFromGenius(query);
        if (foundContent != null) {
          debugPrint('[LyricsRepo] Successfully fetched Genius lyrics');
        }
      }

      // If lyrics are found, write to cache and return
      if (foundContent != null) {
        final contentToCache = isUnisonVideo
            ? '[source: unison-video]\n$foundContent'
            : foundContent;
        await localSource.saveToCache(track, contentToCache);
        return (
          lines: LyricsParser.parse(foundContent),
          isVideoSynced: isUnisonVideo,
        );
      }
    }

    // Default Cache fallback
    if (cachedRecord != null) {
      final isVideo = cachedRecord.content.contains('[source: unison-video]');
      return (
        lines: LyricsParser.parse(cachedRecord.content),
        isVideoSynced: isVideo,
      );
    }
    return (lines: <LyricLine>[], isVideoSynced: false);
  }

  bool _verifyDurationMatch(
    List<LyricLine> parsedLines,
    Duration? trackDuration,
  ) {
    if (trackDuration == null ||
        trackDuration == Duration.zero ||
        parsedLines.isEmpty) {
      return true; // If track duration is unknown, bypass
    }
    // Allow plain lyrics fallback
    if (parsedLines.length > 1 &&
        parsedLines[1].timestamp == const Duration(seconds: 2)) {
      return true;
    }
    final lastLineTimestamp = parsedLines.last.timestamp;
    final diff = (trackDuration - lastLineTimestamp).abs();
    // Allow up to a 20-second difference to account for normal trailing silences
    return diff.inSeconds <= 20;
  }
}

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  return LyricsRepository(ref);
});
