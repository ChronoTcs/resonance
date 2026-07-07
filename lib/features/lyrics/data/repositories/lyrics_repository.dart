import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../../../library/data/models/media_item.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../../core/data/services/cache_manager.dart';
import '../../../../core/data/services/data_usage_service.dart';

class LyricsRepository {
  final Ref _ref;

  // Memory Cache for latest processed lyrics
  String? _lastTrackId;
  List<LyricLine>? _lastLyrics;

  // [V20.27 SOTA] In-Flight Mutex Tracker (DDoS Prevention)
  final Map<String, Future<List<LyricLine>>> _inFlightRequests = {};

  LyricsRepository(this._ref);

  Future<List<LyricLine>> getLyrics(
    MediaItem track, {
    String? lyricsFolderPath,
    bool forceSync = false,
  }) async {
    final trackId = track.id ?? track.path;

    // 1. Memory Cache Check (Prevent double parsing for the same track)
    if (_lastTrackId == trackId && _lastLyrics != null && !forceSync) {
      debugPrint('LyricsRepository: [CACHE] Returning memory cached lyrics for $trackId');
      return _lastLyrics!;
    }
    
    // [V20.27 SOTA] Race Condition / In-Flight Mutex Check
    if (!forceSync && _inFlightRequests.containsKey(trackId)) {
      debugPrint('LyricsRepository: [MUTEX] Joining existing in-flight request for $trackId');
      return await _inFlightRequests[trackId]!;
    }

    final future = _fetchAndParseLyrics(track, trackId, lyricsFolderPath, forceSync);
    _inFlightRequests[trackId] = future;
    
    try {
      final result = await future;
      // [V20.27 SOTA] Pemasangan Paksa Memori Cache (Amnesia Fix)
      _lastTrackId = trackId;
      _lastLyrics = result;
      return result;
    } finally {
      _inFlightRequests.remove(trackId);
    }
  }

  Future<List<LyricLine>> _fetchAndParseLyrics(
    MediaItem track,
    String trackId,
    String? lyricsFolderPath,
    bool forceSync,
  ) async {
    final String trackPath = track.path;
    final cacheService = _ref.read(mediaCacheServiceProvider);

    // Determine Identity
    final String songId = track.id ?? trackPath;
    final bool isStreaming = track.isStreaming;


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
      final String fileName =
          (currentTrack.title.isNotEmpty && currentTrack.title != 'Unknown')
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
            '${trackPath.substring(0, trackPath.lastIndexOf('.'))}.lrc';
        final file = File(lrcPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          return _parseLrc(content);
        }
      }
    }

    // 3. Check Cache (For Streaming/Online Tracks)
    final cacheDir = await _ref.read(cacheManagerProvider).getStreamLyricsDir();
    final String saveId = cacheService.getSafeFilename(songId);
    final File cachedFile = File(p.join(cacheDir.path, '$saveId.lrc'));

    String? cachedContent;
    bool cachedIsSynced = false;

    if (await cachedFile.exists()) {
      cachedContent = await cachedFile.readAsString();
      cachedIsSynced = _hasTimeTags(cachedContent);
      debugPrint(
        'LyricsRepository: Cache HIT. Synced: $cachedIsSynced',
      );
      
      // If synced, return immediately. If plain and offline, return plain.
      // If plain and online, we will try to "Upgrade" below.
      if (cachedIsSynced || !isStreaming) {
        return _parseLrc(cachedContent);
      }
    }

    // 4. Fetch from LRCLIB (Online only)
    if (isStreaming &&
        currentTrack.title.isNotEmpty &&
        currentTrack.title != songId) {
      debugPrint(
        'LyricsRepository: ${cachedContent != null ? "Upgrading plain cache..." : "Fetching from LRCLIB..."}',
      );
      
      final durationSecs = currentTrack.duration?.inSeconds ?? 0;

      // Extract metadata from hyphenated title: "Artist - Title"
      final parsed = _parseHyphenatedTitle(currentTrack.title, currentTrack.artist ?? '');
      final cleanTitle = parsed.title;
      final cleanArtist = parsed.artist;

      final defaultTitle = _cleanTitle(currentTrack.title);
      final defaultArtist = _cleanArtist(currentTrack.artist ?? '');

      String? bestSynced;
      String? bestPlain;

      // Helper to process search results
      void processResult(String? result) {
        if (result == null) return;
        if (_hasTimeTags(result)) {
          bestSynced ??= result;
        } else {
          bestPlain ??= result;
        }
      }

      // ── TRY 1: Parsed hyphenated artist & title (Highly accurate for YouTube) ──
      if (cleanArtist.isNotEmpty) {
        // Step A: Exact Match with Duration
        if (durationSecs > 0) {
          processResult(await _fetchFromLrcLibGet({
            'track_name': cleanTitle,
            'artist_name': cleanArtist,
            'duration': durationSecs.toString(),
          }, 'exact+dur (parsed)'));
        }
        // Step B: Exact Match without Duration
        if (bestSynced == null) {
          processResult(await _fetchFromLrcLibGet({
            'track_name': cleanTitle,
            'artist_name': cleanArtist,
          }, 'exact (parsed)'));
        }
      }

      // ── TRY 2: Default Uploader Metadata (Fallback) ──
      if (bestSynced == null && defaultArtist.isNotEmpty && defaultArtist != cleanArtist) {
        if (durationSecs > 0) {
          processResult(await _fetchFromLrcLibGet({
            'track_name': defaultTitle,
            'artist_name': defaultArtist,
            'duration': durationSecs.toString(),
          }, 'exact+dur (default)'));
        }
        if (bestSynced == null) {
          processResult(await _fetchFromLrcLibGet({
            'track_name': defaultTitle,
            'artist_name': defaultArtist,
          }, 'exact (default)'));
        }
      }

      // ── TRY 3: SEARCH API (Flexible) ──
      if (bestSynced == null) {
        // Prefer parsed hyphen details first, otherwise default
        final queryArtist = cleanArtist.isNotEmpty ? cleanArtist : defaultArtist;
        final queryTitle = cleanArtist.isNotEmpty ? cleanTitle : defaultTitle;
        final query = queryArtist.isNotEmpty ? '$queryTitle $queryArtist' : queryTitle;
        processResult(await _fetchFromLrcLibSearch({
          'q': query,
        }, 'searchAPI'));
      }

      // Final decision
      final finalLyrics = bestSynced ?? bestPlain;
      if (finalLyrics != null) {
        // Only overwrite cache if we found a synced version OR if we had nothing
        if (bestSynced != null || cachedContent == null) {
           return _handleFoundLyrics(finalLyrics, cachedFile);
        }
      }
    }

    return cachedContent != null ? _parseLrc(cachedContent) : [];
  }

  bool _hasTimeTags(String content) {
    return content.contains(RegExp(r'\[\d{1,3}:\d{2}[.:]\d{2,3}\]'));
  }

  /// Saves lyrics to disk and returns the parsed lines.
  Future<List<LyricLine>> _handleFoundLyrics(
    String lyrics,
    File cachedFile,
  ) async {
    try {
      await cachedFile.writeAsString(lyrics);
      debugPrint(
        'LyricsRepository: Saved new lyrics to cache: ${p.basename(cachedFile.path)}',
      );
    } catch (e) {
      debugPrint('LyricsRepository: Cache write error: $e');
    }
    return _parseLrc(lyrics);
  }

  /// Removes YouTube noise and feature tags.
  String _cleanTitle(String title) {
    if (title.isEmpty) return "";
    String clean = title;
    final noiseTerms = [
      "(Official Video)",
      "[Official Video]",
      "(Official Audio)",
      "[Official Audio]",
      "(OFFICIAL MUSIC VIDEO)",
      "(Lyric Video)",
      "(Official Lyric Video)",
      "(Lyrics)",
      "[Lyrics]",
      "(HD)",
      "(HQ)",
      "(4K)",
      "Official Music Video",
      "Official Video",
      "Official Audio",
      "Lyric Video",
      "MV",
      "[MV]",
      "(MV)",
      "High Quality",
    ];
    for (var noise in noiseTerms) {
      clean = clean.replaceAll(
        RegExp(RegExp.escape(noise), caseSensitive: false),
        "",
      );
    }
    // Remove (feat. ...) or (ft. ...)
    final featRegex = RegExp(
      r'[\(\[]\s*(feat\.|ft\.|with)\s+.*[\)\]]',
      caseSensitive: false,
    );
    clean = clean.replaceAll(featRegex, "");
    return clean.trim();
  }

  /// Extracts primary artist and removes Topic/VEVO suffix.
  String _cleanArtist(String artist) {
    if (artist.isEmpty) return "";
    // Take only primary artist (before comma)
    String primary = artist.split(',')[0].trim();
    final suffixes = [" - Topic", "VEVO", " Official", " Music", " TV"];
    for (var suffix in suffixes) {
      if (primary.endsWith(suffix)) {
        primary = primary.substring(0, primary.length - suffix.length).trim();
      }
    }
    return primary;
  }

  /// Extracts actual artist and title from a hyphenated track title if present.
  ({String artist, String title}) _parseHyphenatedTitle(String title, String defaultArtist) {
    String cleanedTitle = _cleanTitle(title);
    
    // Strip common YouTube vertical bar suffix noise: "Title | Lyrics", "Title | Official"
    if (cleanedTitle.contains('|')) {
      cleanedTitle = cleanedTitle.split('|')[0].trim();
    }
    
    // Strip uploader/channel prefix if it is prepended to the title (e.g. "Uploader Artist - Title")
    final cleanDefaultArtist = _cleanArtist(defaultArtist);
    if (cleanDefaultArtist.isNotEmpty && cleanedTitle.startsWith(cleanDefaultArtist)) {
      cleanedTitle = cleanedTitle.substring(cleanDefaultArtist.length).trim();
      // Remove any leading hyphens or spaces left over
      if (cleanedTitle.startsWith('-')) {
        cleanedTitle = cleanedTitle.substring(1).trim();
      }
    }

    if (cleanedTitle.contains(' - ')) {
      final parts = cleanedTitle.split(' - ');
      final potentialArtist = parts[0].trim();
      final potentialTitle = parts.sublist(1).join(' - ').trim();
      if (potentialArtist.isNotEmpty && potentialTitle.isNotEmpty) {
        return (artist: potentialArtist, title: potentialTitle);
      }
    }
    return (artist: cleanDefaultArtist, title: cleanedTitle);
  }

  Future<String?> _fetchFromLrcLibGet(
    Map<String, String> params,
    String label,
  ) async {
    final uri = Uri.parse(
      'https://lrclib.net/api/get',
    ).replace(queryParameters: params);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final data = jsonDecode(response.body);
        final lyrics =
            (data['syncedLyrics'] as String?) ??
            (data['plainLyrics'] as String?);
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          debugPrint('LyricsRepository: Found lyrics via [$label]');
          return lyrics;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchFromLrcLibSearch(
    Map<String, String> params,
    String label,
  ) async {
    final uri = Uri.parse(
      'https://lrclib.net/api/search',
    ).replace(queryParameters: params);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final List<dynamic> data = jsonDecode(response.body);
        
        if (data.isNotEmpty) {
          // PUTARAN 1: Cari dengan ketat HANYA lirik yang tersinkronisasi di seluruh hasil
          for (var item in data) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              debugPrint('LyricsRepository: Found SYNCED lyrics via [$label]');
              return synced; // Langsung kembalikan lirik yang ada waktu/tag-nya
            }
          }

          // PUTARAN 2: Jika satupun tidak ada yang sinkron, ambil plain text dari hasil teratas (Fallback)
          final bestMatch = data.first;
          final plain = bestMatch['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) {
            debugPrint('LyricsRepository: Found PLAIN lyrics via [$label]');
            return plain;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  List<LyricLine> _parseLrc(String content) {
    if (content.isEmpty) return [];

    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];
    final timeTagRegex = RegExp(r'\[(\d{1,3}):(\d{2})[.:](\d{2,3})\]');

    for (var line in lines) {
      final match = timeTagRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        String millisStr = match.group(3)!;
        if (millisStr.length == 2) millisStr += '0';
        final milliseconds = int.parse(millisStr.substring(0, 3));

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        final text = line.substring(match.end).trim();
        // Allow empty text lines for spacing, but don't add if both text and time are missing
        parsedLines.add(LyricLine(timestamp: duration, text: text));
      }
    }

    // FALLBACK: If no time tags found, treat as plain text with 2s intervals
    if (parsedLines.isEmpty && content.trim().isNotEmpty) {
      debugPrint('LyricsRepository: No time tags found. Parsing as plain text.');
      final plainLines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (int i = 0; i < plainLines.length; i++) {
        parsedLines.add(
          LyricLine(
            timestamp: Duration(seconds: i * 2), // Mock timing
            text: plainLines[i].trim(),
          ),
        );
      }
    }

    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    debugPrint('LyricsRepository: Successfully parsed ${parsedLines.length} lines.');
    return parsedLines;
  }
}

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  return LyricsRepository(ref);
});
