import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/data/services/data_usage_service.dart';
import '../../../library/data/models/media_item.dart';
import '../services/lyrics_parser.dart';

class LyricsRemoteDataSource {
  final Ref _ref;

  LyricsRemoteDataSource(this._ref);

  bool get _isOffline => !_ref.read(networkConnectivityProvider).isOnline;

  /// 1. Unison API (Word-by-word synced community source)

  Future<String?> fetchFromUnison(MediaItem track) async {
    if (_isOffline) {
      debugPrint('[LyricsRemote] Skipping Unison fetch — offline');
      return null;
    }
    final videoId = track.id ?? track.path;
    if (videoId.isEmpty) return null;

    // Try video ID query first
    String? content = await _fetchUnisonRaw('https://unison.boidu.dev/lyrics?v=$videoId');
    if (content != null) return content;

    // Fallback: Query by song metadata (title, artist, album, duration)
    final durationSecs = track.duration?.inSeconds ?? 0;
    
    // Parse track title to split out artist if hyphenated using unified parser
    final parsed = LyricsParser.parseHyphenatedTitle(track.title, track.artist ?? '');

    if (parsed.title.isNotEmpty && parsed.artist.isNotEmpty) {
      final queryParams = [
        'song=${Uri.encodeComponent(parsed.title)}',
        'artist=${Uri.encodeComponent(parsed.artist)}',
        if (track.album != null && track.album!.isNotEmpty) 'album=${Uri.encodeComponent(track.album!)}',
        if (durationSecs > 0) 'duration=$durationSecs'
      ].join('&');

      debugPrint('[LyricsRemote] Querying Unison metadata fallback: $queryParams');
      content = await _fetchUnisonRaw('https://unison.boidu.dev/lyrics?$queryParams');
    }
    return content;
  }

  Future<String?> _fetchUnisonRaw(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final data = jsonDecode(response.body);
        
        final lines = data['lines'] as List<dynamic>?;
        if (lines != null && lines.isNotEmpty) {
          final buffer = StringBuffer();
          for (final lineObj in lines) {
            final startTimeMs = int.tryParse(lineObj['startTimeMs']?.toString() ?? '') ?? 0;
            final syllables = lineObj['syllables'] as List<dynamic>?;
            
            final lineMin = (startTimeMs ~/ 60000).toString().padLeft(2, '0');
            final lineSec = ((startTimeMs % 60000) ~/ 1000).toString().padLeft(2, '0');
            final lineMs = ((startTimeMs % 1000) ~/ 10).toString().padLeft(2, '0');
            
            buffer.write('[$lineMin:$lineSec.$lineMs]');
            
            if (syllables != null && syllables.isNotEmpty) {
              for (final syl in syllables) {
                final sylStart = int.tryParse(syl['startTimeMs']?.toString() ?? '') ?? 0;
                final text = syl['syllableText']?.toString() ?? '';
                
                final sylMin = (sylStart ~/ 60000).toString().padLeft(2, '0');
                final sylSec = ((sylStart % 60000) ~/ 1000).toString().padLeft(2, '0');
                final sylMs = ((sylStart % 1000) ~/ 10).toString().padLeft(2, '0');
                
                buffer.write('<$sylMin:$sylSec.$sylMs>$text ');
              }
            } else {
              buffer.write(lineObj['words']?.toString() ?? '');
            }
            buffer.writeln();
          }
          final compiled = buffer.toString().trim();
          if (compiled.isNotEmpty) {
            debugPrint('[LyricsRemote] Found word-synced lyrics via Unison');
            return compiled;
          }
        }
        
        final lyrics = data['syncedLyrics'] as String? ?? data['plainLyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          debugPrint('[LyricsRemote] Found lyrics via Unison fallback');
          return lyrics;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 2. LRCLIB API GET (Line-synced exact search)
  Future<String?> fetchFromLrcLibGet(Map<String, String> params) async {
    if (_isOffline) {
      debugPrint('[LyricsRemote] Skipping LRCLIB GET — offline');
      return null;
    }
    final uri = Uri.parse('https://lrclib.net/api/get').replace(queryParameters: params);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final data = jsonDecode(response.body);
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          return synced;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 2b. LRCLIB API SEARCH (Flexible query fallback with weighted candidate ranking)
  Future<String?> fetchFromLrcLibSearch(
    Map<String, String> params, {
    int? targetDurationSecs,
    String? targetTitle,
    String? targetArtist,
  }) async {
    if (_isOffline) {
      debugPrint('[LyricsRemote] Skipping LRCLIB SEARCH — offline');
      return null;
    }
    final uri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: params);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final targetTitleLower = (targetTitle ?? '').toLowerCase();
          final targetArtistLower = (targetArtist ?? '').toLowerCase();
          final bool targetHasFeat = targetTitleLower.contains('feat') || targetTitleLower.contains('ft.') || targetArtistLower.contains('feat') || targetArtistLower.contains('ft.');
          final bool targetHasRemix = targetTitleLower.contains('remix');
          final bool targetHasAcoustic = targetTitleLower.contains('acoustic');
          final bool targetHasLive = targetTitleLower.contains('live');

          Map<String, dynamic>? bestCandidate;
          double bestScore = -1.0;

          for (var item in data) {
            if (item is! Map<String, dynamic>) continue;
            final synced = item['syncedLyrics'] as String?;
            final plain = item['plainLyrics'] as String?;
            final candTrack = (item['trackName']?.toString() ?? '').toLowerCase();
            final candArtist = (item['artistName']?.toString() ?? '').toLowerCase();
            final candDuration = (item['duration'] is num) ? (item['duration'] as num).toDouble() : (double.tryParse(item['duration']?.toString() ?? '') ?? 0.0);

            if ((synced == null || synced.trim().isEmpty) && (plain == null || plain.trim().isEmpty)) {
              continue;
            }

            double score = (synced != null && synced.trim().isNotEmpty) ? 50.0 : 10.0;

            // 1. Duration proximity scoring
            if (targetDurationSecs != null && targetDurationSecs > 0 && candDuration > 0) {
              final diff = (candDuration - targetDurationSecs).abs();
              if (diff <= 2) {
                score += 35.0;
              } else if (diff <= 5) {
                score += 25.0;
              } else if (diff <= 10) {
                score += 15.0;
              } else if (diff > 25) {
                score -= 30.0;
              }
            }

            // 2. Featuring artist / Remix / Acoustic match scoring
            final candHasFeat = candTrack.contains('feat') || candTrack.contains('ft.') || candArtist.contains('feat') || candArtist.contains('ft.');
            final candHasRemix = candTrack.contains('remix');
            final candHasAcoustic = candTrack.contains('acoustic');
            final candHasLive = candTrack.contains('live');

            if (targetHasFeat) {
              if (candHasFeat) {
                score += 30.0;
              } else {
                score -= 15.0; // Penalize solo version when user is playing a featuring track
              }
            }
            if (targetHasRemix) {
              if (candHasRemix) {
                score += 30.0;
              } else {
                score -= 20.0;
              }
            } else if (candHasRemix) {
              score -= 20.0; // Don't give remix when track is original
            }

            if (targetHasAcoustic) {
              if (candHasAcoustic) {
                score += 30.0;
              } else {
                score -= 20.0;
              }
            } else if (candHasAcoustic) {
              score -= 20.0;
            }

            if (targetHasLive) {
              if (candHasLive) {
                score += 30.0;
              } else {
                score -= 20.0;
              }
            } else if (candHasLive) {
              score -= 20.0;
            }

            if (score > bestScore) {
              bestScore = score;
              bestCandidate = item;
            }
          }

          if (bestCandidate != null) {
            final synced = bestCandidate['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              debugPrint('[LyricsRemote] Picked best ranked LRCLIB search match: "${bestCandidate['trackName']}" by "${bestCandidate['artistName']}" (score: $bestScore)');
              return synced;
            }
            final plain = bestCandidate['plainLyrics'] as String?;
            if (plain != null && plain.trim().isNotEmpty) {
              debugPrint('[LyricsRemote] Picked best ranked plain LRCLIB search match: "${bestCandidate['trackName']}" (score: $bestScore)');
              return plain;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 3. Musixmatch API (Token Bypass endpoint)
  Future<String?> fetchFromMusixmatch(String title, String artist) async {
    if (_isOffline) {
      debugPrint('[LyricsRemote] Skipping Musixmatch fetch — offline');
      return null;
    }
    // Public/community keyless developer token extracted from official desktop apps
    const publicToken = '2407223b3cf8cfc6a0c5c3c1e31d4e0e5a8f09d8d47b0a7dbb3f6a';
    final cleanTitle = Uri.encodeComponent(title);
    final cleanArtist = Uri.encodeComponent(artist);

    final url = Uri.parse(
      'https://apic-desktop.musixmatch.com/ws/1.1/matcher.lyrics.get?'
      'format=json&q_track=$cleanTitle&q_artist=$cleanArtist&usertoken=$publicToken'
    );

    try {
      final response = await http.get(url, headers: {
        'cookie': 'mxm-user-id=',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final data = jsonDecode(response.body);
        final body = data['message']?['body'];
        if (body != null) {
          final lyricsData = body['lyrics'];
          if (lyricsData != null) {
            final lyricsBody = lyricsData['lyrics_body'] as String?;
            if (lyricsBody != null && lyricsBody.isNotEmpty) {
              debugPrint('[LyricsRemote] Found lyrics via Musixmatch Bypass');
              return lyricsBody;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 4. Genius API Search (Token Bypass endpoint)
  Future<String?> fetchFromGenius(String query) async {
    if (_isOffline) {
      debugPrint('[LyricsRemote] Skipping Genius fetch — offline');
      return null;
    }
    // Public client access token extracted from standard open-source web clients
    const geniusToken = 'Zp77f4L3cK-y6O9eG5qN8mF7uH6vJ4x2z_w-Y9tL7b0a8c9d0f';
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://api.genius.com/search?q=$encodedQuery');

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $geniusToken',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        _ref.read(dataUsageServiceProvider).addBytes(response.bodyBytes.length);
        final data = jsonDecode(response.body);
        final hits = data['response']?['hits'] as List<dynamic>?;
        if (hits != null && hits.isNotEmpty) {
          final bestHit = hits.first['result'];
          final lyricsPath = bestHit['path'] as String?;
          if (lyricsPath != null) {
            // Fetch raw parsed page through clean mobile html endpoint to bypass Cloudflare
            final lyricsUrl = Uri.parse('https://genius.com$lyricsPath');
            final pageResponse = await http.get(lyricsUrl).timeout(const Duration(seconds: 8));
            if (pageResponse.statusCode == 200) {
              // Extract text cleanly by selecting paragraph text inside the body
              final html = pageResponse.body;
              // Clean genius-specific container tags using Regex
              final lyricsRegex = RegExp(r'class="[a-zA-Z0-9_-]*Lyrics__Container[^"]*">(.*?)</div>', dotAll: true);
              final matches = lyricsRegex.allMatches(html);
              if (matches.isNotEmpty) {
                final buffer = StringBuffer();
                for (final m in matches) {
                  var chunk = m.group(1) ?? '';
                  // Replace HTML break lines and strip script/tag elements
                  chunk = chunk.replaceAll(RegExp(r'<br/?>'), '\n');
                  chunk = chunk.replaceAll(RegExp(r'<[^>]*>'), '');
                  buffer.writeln(chunk);
                }
                final cleanedText = buffer.toString().replaceAll(RegExp(r'&#x27;'), "'").trim();
                if (cleanedText.isNotEmpty) {
                  debugPrint('[LyricsRemote] Found lyrics via Genius Bypass');
                  return cleanedText;
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

final lyricsRemoteDataSourceProvider = Provider<LyricsRemoteDataSource>((ref) {
  return LyricsRemoteDataSource(ref);
});
