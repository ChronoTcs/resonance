import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'rpc_cache_service.dart';
import 'media_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_manager.dart';

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final rpcCache = ref.watch(rpcCacheServiceProvider);
  final service = DiscordRpcService(ref, rpcCache);
  ref.onDispose(() => service.dispose());
  return service;
});

class DiscordRpcService {
  final Ref _ref;
  final RpcCacheService _rpcCache;
  DiscordRpcService(this._ref, this._rpcCache);

  static const _channel = MethodChannel('com.chronostudio.resonance/discord_rpc');
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  String? _lastTrackId;
  String _currentAlbumArtKey = 'resonance_logo';

  // Throttling and Sequencing
  bool _lastPlayingState = false;
  final Map<String, Future<({String? artworkUrl, String? albumName})>>
  _inFlightMetadataRequests = {};
  // throttle reconnect to once per 30s — handles Discord opening after app startup
  int _lastInitAttemptMs = 0;

  // Payload deduplication state to prevent exceeding Discord's 5 updates / 20s rate limit
  String? _lastSentDetails;
  String? _lastSentState;
  String? _lastSentLargeImage;
  String? _lastSentLargeText;
  bool? _lastSentIsPlaying;
  int? _lastSentStartMs;
  int? _lastSentEndMs;
  String? _lastSentVideoId;

  Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isAndroid) return;

    try {
      final ok = await _channel.invokeMethod<bool>('initialize', {
        'applicationId': '1481352932568862823',
      });
      _isInitialized = ok ?? true;
      debugPrint(
        '[DiscordRPC] Initialized successfully with Client ID: 1481352932568862823',
      );
    } catch (e) {
      debugPrint('[DiscordRPC] Failed to initialize Discord RPC: $e');
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
    final cachedPath = await _ref
        .read(mediaCacheServiceProvider)
        .getCachedArtPath(songId);
    if (cachedPath != null && cachedPath.isNotEmpty) {
      debugPrint('[DiscordRPC] Art cache hit (file) for $songId');
      // Fall through to Tier 2 which may have a network URL cached
    }

    // Tier 2: SharedPreferences string-key cache (RpcCacheService)
    return _rpcCache.getCachedAlbumArtUrl(
      track.artist ?? '',
      track.title,
      () async {
        // Tier 3: iTunes network fetch — skip if offline
        if (!_ref.read(networkConnectivityProvider).isOnline) {
          debugPrint('[DiscordRPC] Offline — skipping iTunes fetch for ${track.title}');
          return null;
        }
        final res = await _fetchAlbumArtAndMetadata(track.title, track.artist);
        final url = res.artworkUrl;
        if (url != null && url.isNotEmpty) {
          // Back-fill into MediaCacheService with forceOverwrite so it replaces low-res art
          unawaited(
            _ref
                .read(mediaCacheServiceProvider)
                .cacheArtwork(songId, url, forceOverwrite: true),
          );
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
    _lastPlayingState = false;
    _currentAlbumArtKey = 'resonance_logo';
  }

  void _resetLastSentCache() {
    _lastSentDetails = null;
    _lastSentState = null;
    _lastSentLargeImage = null;
    _lastSentLargeText = null;
    _lastSentIsPlaying = null;
    _lastSentStartMs = null;
    _lastSentEndMs = null;
    _lastSentVideoId = null;
  }

  /// Resolves iTunes artwork URL and official album metadata for [track].
  Future<({String? artworkUrl, String? albumName})> resolveArtworkAndMetadata(
    MediaItem track,
  ) async {
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      debugPrint('[DiscordRPC] Offline — skipping iTunes metadata fetch for ${track.title}');
      return (artworkUrl: null, albumName: null);
    }
    final res = await _fetchAlbumArtAndMetadata(track.title, track.artist);
    if (res.artworkUrl != null && res.artworkUrl!.isNotEmpty) {
      unawaited(
        _rpcCache.getCachedAlbumArtUrl(
          track.artist ?? '',
          track.title,
          () async => res.artworkUrl,
        ),
      );
    }
    return res;
  }

  /// Resolves full official metadata (Title, Artist, Album, ReleaseDate, High-Res Artwork) from iTunes.
  Future<({
    String? artworkUrl,
    String? albumName,
    String? trackTitle,
    String? artistName,
    String? releaseDate,
  })> resolveFullTrackInfo(String rawTitle, String? rawArtist) async {
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      debugPrint('[DiscordRPC] Offline — skipping full track info fetch for $rawTitle');
      return (
        artworkUrl: null,
        albumName: null,
        trackTitle: null,
        artistName: null,
        releaseDate: null,
      );
    }
    try {
      final cleanedTitle = _stripMovieSubtitle(rawTitle);
      final queries = _generateSearchQueries(cleanedTitle, rawArtist);
      if (cleanedTitle != rawTitle) {
        queries.add(_generateSearchQueries(rawTitle, rawArtist).first);
      }

      for (final query in queries) {
        try {
          final uri = Uri.parse(
            'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=5',
          );
          final response = await http
              .get(uri)
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty) {
              for (final result in results) {
                final collectionName = result['collectionName'] as String?;
                if (_isBadAlbum(collectionName)) continue;

                final artworkUrl100 = result['artworkUrl100'] as String?;
                String? highResUrl;
                if (artworkUrl100 != null) {
                  highResUrl = artworkUrl100.replaceAll(
                    '100x100bb.jpg',
                    '600x600bb.jpg',
                  );
                }
                final trackTitle = result['trackName'] as String?;
                final artistName = result['artistName'] as String?;
                final releaseDate = result['releaseDate'] as String?;

                return (
                  artworkUrl: highResUrl,
                  albumName: collectionName,
                  trackTitle: trackTitle,
                  artistName: artistName,
                  releaseDate: releaseDate,
                );
              }
            }
          }
        } catch (e) {
          debugPrint('[DiscordRPC] resolveFullTrackInfo query failed ("$query"): $e');
        }
      }
    } catch (e) {
      debugPrint('[DiscordRPC] resolveFullTrackInfo setup error: $e');
    }
    return (
      artworkUrl: null,
      albumName: null,
      trackTitle: null,
      artistName: null,
      releaseDate: null,
    );
  }

  // album names that indicate karaoke/tribute/compilation — never use their art
  static const _kBadAlbumKeywords = [
    'karaoke',
    'tribute',
    'instrumental',
    'sing along',
    'singalong',
    'cover',
    'megatunez',
    'zzang',
    'best pop vol',
    'best hits vol',
  ];

  static bool _isBadAlbum(String? collectionName) {
    if (collectionName == null) return false;
    final lower = collectionName.toLowerCase();
    return _kBadAlbumKeywords.any(lower.contains);
  }

  /// Strips movie/show subtitle parentheticals that over-specify the iTunes query
  /// e.g. "Sunflower (Spider-Man: Into the Spider-Verse)" → "Sunflower"
  static String _stripMovieSubtitle(String title) {
    return title
        .replaceAll(
          RegExp(
            r'\s*\([^)]*(?:verse|movie|film|soundtrack|ost|part|vol\.|from the|spider|into|the)[^)]*\)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  Future<({String? artworkUrl, String? albumName})> _fetchAlbumArtAndMetadata(
    String rawTitle,
    String? rawArtist,
  ) async {
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      debugPrint('[DiscordRPC] Offline — skipping iTunes album art fetch for "$rawTitle"');
      return (artworkUrl: null, albumName: null);
    }

    final key = '${rawTitle.toLowerCase().trim()}||${(rawArtist ?? '').toLowerCase().trim()}';
    final inFlight = _inFlightMetadataRequests[key];
    if (inFlight != null) {
      debugPrint('[DiscordRPC] Reusing in-flight iTunes request for "$rawTitle"');
      return inFlight;
    }

    final future = _executeFetchAlbumArtAndMetadata(rawTitle, rawArtist);
    _inFlightMetadataRequests[key] = future;
    try {
      return await future;
    } finally {
      _inFlightMetadataRequests.remove(key);
    }
  }

  Future<({String? artworkUrl, String? albumName})> _executeFetchAlbumArtAndMetadata(
    String rawTitle,
    String? rawArtist,
  ) async {
    try {
      // Strip movie/show subtitles for a broader, popularity-ranked search
      final cleanedTitle = _stripMovieSubtitle(rawTitle);
      final queries = _generateSearchQueries(cleanedTitle, rawArtist);
      // Append original title as final fallback so nothing is lost
      if (cleanedTitle != rawTitle) {
        queries.add(_generateSearchQueries(rawTitle, rawArtist).first);
      }

      for (final query in queries) {
        try {
          // Try limit=5 to have candidates to skip bad album results
          final uri = Uri.parse(
            'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=5',
          );
          debugPrint(
            '[DiscordRPC] Fetching album art & metadata with query: "$query"',
          );
          final response = await http
              .get(uri)
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty) {
              // Skip karaoke/tribute/compilation results; pick first legitimate hit
              for (final result in results) {
                final collectionName = result['collectionName'] as String?;
                if (_isBadAlbum(collectionName)) {
                  debugPrint('[DiscordRPC] Skipping bad album: $collectionName');
                  continue;
                }
                final artworkUrl100 = result['artworkUrl100'] as String?;
                String? highResUrl;
                if (artworkUrl100 != null) {
                  highResUrl = artworkUrl100.replaceAll(
                    '100x100bb.jpg',
                    '500x500bb.jpg',
                  );
                  debugPrint(
                    '[DiscordRPC] Found official artwork -> $highResUrl, album: $collectionName',
                  );
                }
                return (artworkUrl: highResUrl, albumName: collectionName);
              }
              // All candidates were bad — try next query permutation
              debugPrint(
                '[DiscordRPC] All ${results.length} results were bad albums for query: "$query"',
              );
            }
          }
        } catch (e) {
          debugPrint('[DiscordRPC] Query failed ("$query"): $e');
        }
      }
      debugPrint(
        '[DiscordRPC] No results found on iTunes for rawTitle: "$rawTitle", rawArtist: "$rawArtist"',
      );
    } catch (e) {
      debugPrint('[DiscordRPC] Failed to fetch album art from iTunes: $e');
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
        cleanArtist = cleanArtist
            .substring(0, cleanArtist.length - suffix.length)
            .trim();
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

  Future<String?> updatePresence(
    MediaItem? track,
    Duration position,
    Duration duration,
    bool isPlaying,
  ) async {
    // Lazy reconnect: Discord may have launched after app startup.
    // Retry initialize() at most once every 30s to avoid IPC spam.
    if (!_isInitialized) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastInitAttemptMs > 30000) {
        _lastInitAttemptMs = now;
        await initialize();
      }
      if (!_isInitialized) return null;
    }

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

    final effectiveDuration = duration > Duration.zero
        ? duration
        : (track.duration ?? Duration.zero);
    final endTimestamp = effectiveDuration.inMilliseconds > 0
        ? startTimestamp + effectiveDuration.inMilliseconds
        : null;

    // 1. Pause Guard: send presence once on pause transition, then stay silent on position ticks
    final isTrackChanged = _lastTrackId != currentTrackId;
    final isStateChanged = _lastPlayingState != isPlaying;

    // Resolve best currently available artwork key (cached iTunes -> track HTTP URL -> existing HTTP key -> fallback logo)
    final syncCached = _ref
        .read(rpcCacheServiceProvider)
        .getCachedAlbumArtUrlSync(track.artist ?? '', track.title);
    if (syncCached != null && syncCached.isNotEmpty) {
      _currentAlbumArtKey = syncCached;
    } else if (track.thumbnailUrl != null &&
        track.thumbnailUrl!.startsWith('http')) {
      _currentAlbumArtKey = track.thumbnailUrl!;
    } else if (isTrackChanged) {
      _currentAlbumArtKey = 'resonance_logo';
    }

    if (!isPlaying) {
      if (isStateChanged || isTrackChanged) {
        _lastPlayingState = isPlaying;
        _lastTrackId = currentTrackId;

        _sendActivity(
          track,
          false,
          startTimestamp,
          null,
          _currentAlbumArtKey,
          resolvedVideoId,
        );
      }
      return _currentAlbumArtKey.startsWith('http') ? _currentAlbumArtKey : null;
    }

    _lastPlayingState = isPlaying;
    if (isTrackChanged) {
      _lastTrackId = currentTrackId;
    }

    _sendActivity(
      track,
      isPlaying,
      startTimestamp,
      endTimestamp,
      _currentAlbumArtKey,
      resolvedVideoId,
    );
    return _currentAlbumArtKey.startsWith('http') ? _currentAlbumArtKey : null;
  }

  Future<String?> _findVideoIdFromLrcCache(String songId) async {
    try {
      final cacheDir = await _ref
          .read(cacheManagerProvider)
          .getStreamLyricsDir();
      final File cachedFile = File(p.join(cacheDir.path, '$songId.lrc'));
      if (await cachedFile.exists()) {
        final content = await cachedFile.readAsString();
        // Parse metadata tags from the top of cached LRC files
        for (final line in content.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('[unison_id:') && trimmed.endsWith(']')) {
            return trimmed
                .replaceFirst('[unison_id:', '')
                .replaceFirst(']', '')
                .trim();
          }
          if (trimmed.startsWith('[video_id:') && trimmed.endsWith(']')) {
            return trimmed
                .replaceFirst('[video_id:', '')
                .replaceFirst(']', '')
                .trim();
          }
          // Unison raw files also might contain [id: videoId]
          if (trimmed.startsWith('[id:') && trimmed.endsWith(']')) {
            final possibleId = trimmed
                .replaceFirst('[id:', '')
                .replaceFirst(']', '')
                .trim();
            if (possibleId.length == 11) return possibleId;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _handleChannelError(Object error) {
    debugPrint('[DiscordRPC] Channel error ($error) — resetting RPC connection state');
    _isInitialized = false;
    _lastTrackId = null;
    _lastPlayingState = false;
    _currentAlbumArtKey = 'resonance_logo';
    _resetLastSentCache();
  }

  void _sendActivity(
    MediaItem track,
    bool isPlaying,
    int startTimestamp,
    int? endTimestamp,
    String largeImageKey,
    String? targetVideoId,
  ) async {
    if (!_isInitialized) return;

    final details = track.title;
    final stateStr = track.artist ?? 'Unknown Artist';
    final largeText = track.album ?? 'Resonance';

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = isPlaying ? startTimestamp : null;
    final validEndMs = (isPlaying && endTimestamp != null && endTimestamp > nowMs)
        ? endTimestamp
        : null;

    // Deduplicate identical payloads (within 2000ms timestamp tolerance) to prevent
    // triggering Discord's strict 5 updates / 20s rate-limit cooldown.
    // If endMs transitions from null -> non-null (duration resolved), NEVER deduplicate!
    final sameStart = (startMs == null && _lastSentStartMs == null) ||
        (startMs != null &&
            _lastSentStartMs != null &&
            (startMs - _lastSentStartMs!).abs() <= 2000);
    final sameEnd = (validEndMs == null && _lastSentEndMs == null) ||
        (validEndMs != null &&
            _lastSentEndMs != null &&
            (validEndMs - _lastSentEndMs!).abs() <= 2000);

    final sameTimestamps = sameStart && sameEnd;

    if (_lastSentDetails == details &&
        _lastSentState == stateStr &&
        _lastSentLargeImage == largeImageKey &&
        _lastSentLargeText == largeText &&
        _lastSentIsPlaying == isPlaying &&
        _lastSentVideoId == targetVideoId &&
        sameTimestamps) {
      return;
    }

    _lastSentDetails = details;
    _lastSentState = stateStr;
    _lastSentLargeImage = largeImageKey;
    _lastSentLargeText = largeText;
    _lastSentIsPlaying = isPlaying;
    _lastSentStartMs = startMs;
    _lastSentEndMs = validEndMs;
    _lastSentVideoId = targetVideoId;

    // Both Windows C++ (discord_partner_sdk / discordpp) and Android AIDL
    // expect epoch milliseconds.
    final outStart = startMs;
    final outEnd = validEndMs;

    final hasVideoLink = targetVideoId != null && targetVideoId.isNotEmpty;
    // Windows Discord Desktop supports both timeline scrubber and buttons simultaneously.
    // Android Discord mobile omits buttons while playing to show scrubber, and reveals buttons
    // on pause to trigger AIDL diff update and clear the progress bar.
    final showButtons = Platform.isWindows || !isPlaying;

    debugPrint(
      '[DiscordRPC] Dispatching presence: "$details" by "$stateStr" | playing=$isPlaying | start=$outStart | end=$outEnd',
    );

    try {
      await _channel.invokeMethod('updatePresence', {
        'name': 'Resonance',
        'type': 'listening',
        'details': details,
        'state': stateStr,
        'album': largeText,
        'largeImage': largeImageKey,
        'largeText': largeText,
        'smallImage': null,
        'smallText': null,
        'startTimestamp': outStart,
        'endTimestamp': outEnd,
        'button1Label': showButtons && hasVideoLink ? 'Listen Along' : null,
        'button1Url': showButtons && hasVideoLink
            ? 'https://youtube.com/watch?v=$targetVideoId'
            : null,
        'button2Label': showButtons ? 'Play on Resonance' : null,
        'button2Url': showButtons ? _ref.read(appConfigProvider).releasesUrl : null,
      });
    } catch (e) {
      _handleChannelError(e);
    }
  }

  void clearPresence() {
    _lastTrackId = null;
    _lastPlayingState = false;
    _currentAlbumArtKey = 'resonance_logo';
    _resetLastSentCache();
    if (!_isInitialized) return;
    unawaited(
      _channel.invokeMethod('clearPresence').catchError((e) {
        _handleChannelError(e);
        return null;
      }),
    );
  }

  void dispose() {
    clearPresence();
    if (_isInitialized) {
      unawaited(_channel.invokeMethod('dispose').catchError((_) => null));
    }
    _isInitialized = false;
  }
}
