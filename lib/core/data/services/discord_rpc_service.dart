
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'rpc_cache_service.dart';
import 'media_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_manager.dart';

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final rpcCache = ref.watch(rpcCacheServiceProvider);
  return DiscordRpcService(ref, rpcCache);
});

class DiscordRpcService {
  final Ref _ref;
  final RpcCacheService _rpcCache;
  DiscordRpcService(this._ref, this._rpcCache);

  DiscordRPC? _discord;
  bool _isInitialized = false;
  String? _lastTrackId;
  String _currentAlbumArtKey = 'resonance_logo';

  // Throttling and Sequencing
  int _lastUpdateTime = 0;
  int _requestSessionId = 0;
  bool _lastPlayingState = false;
  // ponytail: single guard — prevents double iTunes fetch from concurrent callers
  bool _isResolvingArt = false;

  Future<void> initialize() async {
    if (!DiscordRPC.isAvailable) return;
    
    try {
      _discord = DiscordRPC();
      await _discord!.initialize('1481352932568862823');
      _isInitialized = true;
      debugPrint('Discord RPC: Initialized successfully with Client ID: 1481352932568862823');
    } catch (e) {
      debugPrint('Failed to initialize Discord RPC: $e');
    }
  }

  /// Resolves the best 1:1 square album art URL for [track].
  /// Lookup order (fastest to slowest):
  ///   1. MediaCacheService by songId (file-based, instant)
  ///   2. RpcCacheService by artist+title (SharedPreferences)
  ///   3. iTunes API fetch (network)
  /// On network fetch, saves back to both caches.
  /// Does NOT touch Discord RPC state — safe to call before updatePresence().
  Future<String?> resolveArtworkOnly(MediaItem track) async {
    return _resolveArtwork(track);
  }

  /// Internal multi-tier artwork resolver.
  Future<String?> _resolveArtwork(MediaItem track) async {
    final songId = track.id ?? track.path;

    // Tier 1: file-based ID cache (MediaCacheService) — zero network, instant
    final cachedPath = await _ref.read(mediaCacheServiceProvider).getCachedArtPath(songId);
    if (cachedPath != null && cachedPath.isNotEmpty) {
      // Convert local path to file URI for Discord (needs http or resonance_logo key)
      // Local cached path cannot be used as Discord large image key — treat as miss for Discord
      // but return the path so callers (SMTC/AudioService) can use it.
      debugPrint('Discord RPC: Art cache hit (file) for $songId');
      // Fall through to Tier 2 which may have a network URL cached
    }

    // Tier 2: SharedPreferences string-key cache (RpcCacheService)
    return _rpcCache.getCachedAlbumArtUrl(
      track.artist ?? '',
      track.title,
      () async {
        // Tier 3: iTunes network fetch
        final res = await _fetchAlbumArtAndMetadata(track.title, track.artist);
        final url = res.artworkUrl;
        if (url != null && url.isNotEmpty) {
          // Back-fill into MediaCacheService so next lookup for this ID is instant
          _ref.read(mediaCacheServiceProvider).cacheArtwork(songId, url).ignore();
        }
        return url;
      },
    );
  }

  /// Resets Discord's internal track state immediately.
  /// Call at the START of a track change so stale album art from the previous
  /// track cannot bleed into the new track's Rich Presence payload.
  void clearTrackState() {
    _lastTrackId = null;
    _currentAlbumArtKey = 'resonance_logo';
    _requestSessionId++; // Invalidates any in-flight async fetch sessions
  }

  /// Resolves iTunes artwork URL and official album metadata for [track].
  Future<({String? artworkUrl, String? albumName})> resolveArtworkAndMetadata(MediaItem track) async {
    final songId = track.id ?? track.path;
    final res = await _fetchAlbumArtAndMetadata(track.title, track.artist);
    if (res.artworkUrl != null && res.artworkUrl!.isNotEmpty) {
      _ref.read(mediaCacheServiceProvider).cacheArtwork(songId, res.artworkUrl!).ignore();
    }
    return res;
  }

  Future<({String? artworkUrl, String? albumName})> _fetchAlbumArtAndMetadata(String rawTitle, String? rawArtist) async {
    try {
      final queries = _generateSearchQueries(rawTitle, rawArtist);
      
      for (final query in queries) {
        final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
        debugPrint('Discord RPC: Fetching album art & metadata with query: "$query"');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['resultCount'] > 0) {
            final firstResult = data['results'][0];
            final artworkUrl100 = firstResult['artworkUrl100'] as String?;
            final collectionName = firstResult['collectionName'] as String?;
            
            String? highResUrl;
            if (artworkUrl100 != null) {
              highResUrl = artworkUrl100.replaceAll('100x100bb.jpg', '500x500bb.jpg');
              debugPrint('Discord RPC: Found official artwork -> $highResUrl, album: $collectionName');
            }
            return (artworkUrl: highResUrl, albumName: collectionName);
          }
        }
      }
      debugPrint('Discord RPC: No results found on iTunes for rawTitle: "$rawTitle", rawArtist: "$rawArtist"');
    } catch (e) {
      debugPrint('Discord RPC: Failed to fetch album art from iTunes: $e');
    }
    return (artworkUrl: null, albumName: null);
  }

  /// Generates adaptive, multi-permutation queries to handle YouTube clutter,
  /// reversed "Artist - Title" or "Title - Artist", multi-creator lists, and video tags.
  List<String> _generateSearchQueries(String rawTitle, String? rawArtist) {
    final Set<String> candidates = {};

    // 1. Clean video noise brackets & tags
    String cleanTitle = rawTitle;
    final bracketPattern = RegExp(r'\([^)]*\)|\[[^\]]*\]|\{[^}]*\}');
    cleanTitle = cleanTitle.replaceAllMapped(bracketPattern, (match) {
      final text = match.group(0)!.toLowerCase();
      if (text.contains('video') ||
          text.contains('lyric') ||
          text.contains('official') ||
          text.contains('audio') ||
          text.contains('visualizer') ||
          text.contains('mv') ||
          text.contains('remastered')) {
        return '';
      }
      return match.group(0)!;
    }).trim();
    String cleanArtist = (rawArtist ?? '');
    cleanArtist = cleanArtist.replaceAllMapped(bracketPattern, (match) {
      final text = match.group(0)!.toLowerCase();
      if (text.contains('video') ||
          text.contains('lyric') ||
          text.contains('official') ||
          text.contains('audio') ||
          text.contains('visualizer') ||
          text.contains('mv') ||
          text.contains('remastered')) {
        return '';
      }
      return match.group(0)!;
    });

    // Extract primary artist before any featuring or collaborator markers
    for (final delimiter in [',', '&', '•', '/', '|']) {
      if (cleanArtist.contains(delimiter)) {
        cleanArtist = cleanArtist.split(delimiter).first;
      }
    }
    cleanArtist = cleanArtist.trim();

    // Strip "- Topic", "VEVO" suffixes from artist
    for (final suffix in [' - Topic', 'VEVO', ' Official', ' Music']) {
      if (cleanArtist.endsWith(suffix)) {
        cleanArtist = cleanArtist.substring(0, cleanArtist.length - suffix.length).trim();
      }
    }

    // 2. Handle hyphenated titles e.g. "INDAHKUS - MALU MALU" or "MALU MALU - INDAHKUS"
    String? hyphenPart1;
    String? hyphenPart2;
    if (cleanTitle.contains(' - ')) {
      final parts = cleanTitle.split(' - ');
      if (parts.length >= 2) {
        hyphenPart1 = parts[0].trim();
        hyphenPart2 = parts.sublist(1).join(' - ').trim();
      }
    } else if (cleanTitle.contains(' – ')) {
      final parts = cleanTitle.split(' – ');
      if (parts.length >= 2) {
        hyphenPart1 = parts[0].trim();
        hyphenPart2 = parts.sublist(1).join(' – ').trim();
      }
    }

    // Candidate 1: Primary Clean Artist + Clean Title
    if (cleanArtist.isNotEmpty && cleanTitle.isNotEmpty) {
      candidates.add('$cleanArtist $cleanTitle');
    }

    // Candidate 2 & 3: If hyphenated inside title ("Artist - Song" or "Song - Artist")
    if (hyphenPart1 != null && hyphenPart2 != null) {
      candidates.add('$hyphenPart1 $hyphenPart2');
      candidates.add('$hyphenPart2 $hyphenPart1');
      candidates.add(hyphenPart2);
      candidates.add(hyphenPart1);
    }

    // Candidate 4: Clean Title only
    if (cleanTitle.isNotEmpty) {
      candidates.add(cleanTitle);
    }

    // Candidate 5: Raw Title + Raw Primary Artist fallback
    if (rawArtist != null && rawArtist.isNotEmpty) {
      candidates.add('${rawArtist.split(',').first.trim()} $rawTitle');
    }

    return candidates.where((q) => q.trim().isNotEmpty).toList();
  }

  Future<String?> updatePresence(MediaItem? track, Duration position, Duration duration, bool isPlaying) async {
    if (!_isInitialized) return null;

    if (track == null) {
      clearPresence();
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final currentTrackId = '${track.title}-${track.artist}';
    
    // Pre-resolve YouTube Video ID fallback if it is a local track
    String? resolvedVideoId;
    if (track.setVideoId != null && track.setVideoId!.isNotEmpty) {
      resolvedVideoId = track.setVideoId;
    } else if (track.id != null && !track.id!.startsWith('loc_')) {
      resolvedVideoId = track.id;
    } else if (track.id != null && track.id!.startsWith('loc_')) {
      resolvedVideoId = await _findVideoIdFromLrcCache(track.id!);
    }
    
    final startTimestamp = now - position.inMilliseconds;

    // 1. Pause Guard: send presence once on pause transition, then stay silent on position ticks
    final isTrackChanged = _lastTrackId != currentTrackId;
    final isStateChanged = _lastPlayingState != isPlaying;

    if (!isPlaying) {
      if (isStateChanged || isTrackChanged) {
        _lastPlayingState = isPlaying;
        _lastTrackId = currentTrackId;
        _lastUpdateTime = now;

        if (isTrackChanged) {
          // New track arrived while paused/stopped (common in auto-advance):
          // Reset art key immediately so old track's URL never bleeds into this track.
          _currentAlbumArtKey = (track.thumbnailUrl != null && track.thumbnailUrl!.startsWith('http'))
              ? track.thumbnailUrl!
              : 'resonance_logo';
          _sendActivity(track, false, startTimestamp, null, _currentAlbumArtKey, resolvedVideoId);

          // Kick off background artwork resolution so the URL is ready when play resumes.
          final artSession = _requestSessionId;
          _resolveArtwork(track).then((url) {
            if (url != null && url.isNotEmpty &&
                _requestSessionId == artSession &&
                _lastTrackId == currentTrackId) {
              _currentAlbumArtKey = url;
              // No sendActivity here — the playing stream will push it when playback starts.
            }
          }).ignore();
        } else {
          // Same track, just paused — send once with existing art key.
          _sendActivity(track, false, startTimestamp, null, _currentAlbumArtKey, resolvedVideoId);
        }
      }
      return null;
    }

    // 2. Playing throttle guard
    if (!isTrackChanged && !isStateChanged && (now - _lastUpdateTime < 2000)) {
      return _currentAlbumArtKey.startsWith('http') ? _currentAlbumArtKey : null;
    }

    _lastUpdateTime = now;
    _lastPlayingState = isPlaying;

    final endTimestamp = duration.inMilliseconds > 0
        ? startTimestamp + duration.inMilliseconds
        : null;

    // 3. Handle New Track Session
    if (isTrackChanged) {
      _lastTrackId = currentTrackId;
      _currentAlbumArtKey = (track.thumbnailUrl != null && track.thumbnailUrl!.startsWith('http'))
          ? track.thumbnailUrl!
          : 'resonance_logo';
      final currentSession = ++_requestSessionId;
      _isResolvingArt = false; // reset guard for new track

      _sendActivity(
        track,
        isPlaying,
        startTimestamp,
        endTimestamp,
        _currentAlbumArtKey,
        resolvedVideoId,
      );

      // ponytail: skip if another caller already kicked off resolution for this track
      if (!_isResolvingArt) {
        _isResolvingArt = true;
        final artworkUrl = await _resolveArtwork(track);
        _isResolvingArt = false;

        if (artworkUrl != null && artworkUrl.isNotEmpty && _requestSessionId == currentSession && _lastTrackId == currentTrackId) {
          _currentAlbumArtKey = artworkUrl;
          _sendActivity(
            track,
            isPlaying,
            startTimestamp,
            endTimestamp,
            _currentAlbumArtKey,
            resolvedVideoId,
          );
          return artworkUrl;
        }
      }
    } else {
      _sendActivity(
        track, 
        isPlaying, 
        startTimestamp, 
        endTimestamp,
        _currentAlbumArtKey,
        resolvedVideoId,
      );
    }
    return _currentAlbumArtKey.startsWith('http') ? _currentAlbumArtKey : null;
  }

  Future<String?> _findVideoIdFromLrcCache(String songId) async {
    try {
      final cacheDir = await _ref.read(cacheManagerProvider).getStreamLyricsDir();
      final File cachedFile = File(p.join(cacheDir.path, '$songId.lrc'));
      if (await cachedFile.exists()) {
        final content = await cachedFile.readAsString();
        // Parse metadata tags from the top of cached LRC files
        for (final line in content.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('[unison_id:') && trimmed.endsWith(']')) {
            return trimmed.replaceFirst('[unison_id:', '').replaceFirst(']', '').trim();
          }
          if (trimmed.startsWith('[video_id:') && trimmed.endsWith(']')) {
            return trimmed.replaceFirst('[video_id:', '').replaceFirst(']', '').trim();
          }
          // Unison raw files also might contain [id: videoId]
          if (trimmed.startsWith('[id:') && trimmed.endsWith(']')) {
            final possibleId = trimmed.replaceFirst('[id:', '').replaceFirst(']', '').trim();
            if (possibleId.length == 11) return possibleId;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _sendActivity(MediaItem track, bool isPlaying, int startTimestamp, int? endTimestamp, String largeImageKey, String? targetVideoId) async {
    if (!_isInitialized || _discord == null) return;

    final hasVideoLink = targetVideoId != null && targetVideoId.isNotEmpty;

    _discord!.setPresence(DiscordPresence(
      type: DiscordActivityType.listening,
      state: track.artist ?? 'Unknown Artist',
      details: track.title,
      largeAsset: DiscordAsset(key: largeImageKey, text: track.album ?? 'Resonance'),
      smallAsset: DiscordAsset(
        key: isPlaying ? 'play_icon' : 'pause_icon',
        text: isPlaying ? 'Playing' : 'Paused',
      ),
      timestamps: isPlaying
          ? DiscordTimestamps(
              start: startTimestamp,
              end: endTimestamp,
            )
          : null, // Omit timestamps to keep it cleared
      buttons: isPlaying
          ? null // Omit buttons during active music playback so Discord renders the timeline progress line bar
          : [ // Show custom buttons when paused since the timeline line is hidden
              if (hasVideoLink)
                DiscordButton(
                  label: 'Listen Along',
                  url: 'https://youtube.com/watch?v=$targetVideoId',
                ),
              DiscordButton(
                label: 'Play on Resonance',
                url: _ref.read(appConfigProvider).releasesUrl,
              ),
            ],
    ));
  }

  void clearPresence() {
    if (!_isInitialized || _discord == null) return;
    _discord!.clearPresence();
    _lastTrackId = null;
    _currentAlbumArtKey = 'resonance_logo';
  }

  void dispose() {
    clearPresence();
    _discord?.dispose();
  }
}
