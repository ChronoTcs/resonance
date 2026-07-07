
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_discord_presence/dart_discord_presence.dart';
import '../../../features/library/data/models/media_item.dart';
import 'rpc_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final rpcCache = ref.watch(rpcCacheServiceProvider);
  return DiscordRpcService(rpcCache);
});

class DiscordRpcService {
  final RpcCacheService _rpcCache;
  DiscordRpcService(this._rpcCache);

  DiscordRPC? _discord;
  bool _isInitialized = false;
  String? _lastTrackId;
  String _currentAlbumArtKey = 'resonance_logo';

  // Throttling and Sequencing
  int _lastUpdateTime = 0;
  int _requestSessionId = 0;
  bool _lastPlayingState = false;

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

  Future<String?> _fetchAlbumArtUrl(String title, String? artist) async {
    try {
      // Use only the primary artist to improve iTunes search hit rate
      final primaryArtist = artist?.split(',').first.trim();
      final query = primaryArtist != null ? '$primaryArtist $title' : title;
      final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
      
      debugPrint('Discord RPC: Fetching album art from $uri');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] > 0) {
          final artworkUrl100 = data['results'][0]['artworkUrl100'] as String?;
          if (artworkUrl100 != null) {
            final highResUrl = artworkUrl100.replaceAll('100x100bb.jpg', '500x500bb.jpg');
            debugPrint('Discord RPC: Found artwork -> $highResUrl');
            return highResUrl;
          }
        } else {
          debugPrint('Discord RPC: No results found on iTunes for query: $query');
        }
      } else {
        debugPrint('Discord RPC: iTunes API error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Discord RPC: Failed to fetch album art from iTunes: $e');
    }
    return null;
  }

  Future<String?> updatePresence(MediaItem? track, Duration position, Duration duration, bool isPlaying) async {
    if (!_isInitialized) return null;

    if (track == null) {
      clearPresence();
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final currentTrackId = '${track.title}-${track.artist}';
    
    // 1. Throttling and Session Check
    final isTrackChanged = _lastTrackId != currentTrackId;
    final isStateChanged = _lastPlayingState != isPlaying;
    
    if (!isTrackChanged && !isStateChanged && (now - _lastUpdateTime < 2000)) {
      return _currentAlbumArtKey.startsWith('http') ? _currentAlbumArtKey : null;
    }

    _lastUpdateTime = now;
    _lastPlayingState = isPlaying;

    final startTimestamp = now - position.inMilliseconds;
    final endTimestamp = duration.inMilliseconds > 0 
        ? startTimestamp + duration.inMilliseconds 
        : null;

    // 2. Handle New Track Session
    if (isTrackChanged) {
      _lastTrackId = currentTrackId;
      _currentAlbumArtKey = 'resonance_logo';
      final currentSession = ++_requestSessionId;
      
      _sendActivity(
        track, 
        isPlaying, 
        startTimestamp, 
        endTimestamp,
        _currentAlbumArtKey,
      );

      final artworkUrl = await _rpcCache.getCachedAlbumArtUrl(
        track.artist ?? '', 
        track.title, 
        () => _fetchAlbumArtUrl(track.title, track.artist)
      );
      
      if (artworkUrl != null && _requestSessionId == currentSession && _lastTrackId == currentTrackId) {
        _currentAlbumArtKey = artworkUrl;
        _sendActivity(
          track,
          isPlaying,
          startTimestamp,
          endTimestamp,
          _currentAlbumArtKey,
        );
        return artworkUrl;
      }
    } else {
      _sendActivity(
        track, 
        isPlaying, 
        startTimestamp, 
        endTimestamp,
        _currentAlbumArtKey,
      );
    }
    return _currentAlbumArtKey.startsWith('http') ? _currentAlbumArtKey : null;
  }

  void _sendActivity(MediaItem track, bool isPlaying, int startTimestamp, int? endTimestamp, String largeImageKey) {
    if (!_isInitialized || _discord == null) return;
    
    _discord!.setPresence(DiscordPresence(
      state: track.artist ?? 'Unknown Artist',
      details: track.title,
      largeAsset: DiscordAsset(key: largeImageKey, text: track.album ?? 'Resonance'),
      smallAsset: DiscordAsset(
        key: isPlaying ? 'play_icon' : 'pause_icon',
        text: isPlaying ? 'Playing' : 'Paused',
      ),
      timestamps: DiscordTimestamps(
        start: startTimestamp,
        end: isPlaying ? endTimestamp : null,
      ),
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
