import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart';
import '../../features/library/data/models/media_item.dart';
import 'rpc_cache_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final rpcCache = ref.watch(rpcCacheServiceProvider);
  return DiscordRpcService(rpcCache);
});

class DiscordRpcService {
  final RpcCacheService _rpcCache;
  DiscordRpcService(this._rpcCache);

  bool _isInitialized = false;
  String? _lastTrackId;
  String _currentAlbumArtKey = 'resonance_logo';

  // Throttling and Sequencing
  int _lastUpdateTime = 0;
  int _requestSessionId = 0;
  bool _lastPlayingState = false;

  Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    
    try {
      await FlutterDiscordRPC.initialize('1481352932568862823'); 
      await FlutterDiscordRPC.instance.connect();
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize Discord RPC: $e');
    }
  }

  Future<String?> _fetchAlbumArtUrl(String title, String? artist) async {
    try {
      // Use only the primary artist to improve iTunes search hit rate
      final primaryArtist = artist?.split(',').first.trim();
      final query = primaryArtist != null ? '$primaryArtist $title' : title;
      final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
      
      print('Discord RPC: Fetching album art from $uri');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] > 0) {
          final artworkUrl100 = data['results'][0]['artworkUrl100'] as String?;
          if (artworkUrl100 != null) {
            final highResUrl = artworkUrl100.replaceAll('100x100bb.jpg', '500x500bb.jpg');
            print('Discord RPC: Found artwork -> $highResUrl');
            return highResUrl;
          }
        } else {
          print('Discord RPC: No results found on iTunes for query: $query');
        }
      } else {
        print('Discord RPC: iTunes API error ${response.statusCode}');
      }
    } catch (e) {
      print('Discord RPC: Failed to fetch album art from iTunes: $e');
    }
    return null;
  }

  void updatePresence(MediaItem? track, Duration position, Duration duration, bool isPlaying) async {
    if (!_isInitialized) return;

    if (track == null) {
      clearPresence();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final currentTrackId = '${track.title}-${track.artist}';
    
    // 1. Throttling and Session Check
    final isTrackChanged = _lastTrackId != currentTrackId;
    final isStateChanged = _lastPlayingState != isPlaying;
    
    // If it's the same track, we MUST NOT let a different track ID sneak in 
    // This often happens if Song A's position events arrive after Song B started.
    // If the caller is passing a track that isn't our "current" one, ignore it unless it's a clear transition.
    if (!isTrackChanged && !isStateChanged && (now - _lastUpdateTime < 2000)) {
      return;
    }

    _lastUpdateTime = now;
    _lastPlayingState = isPlaying;

    final startTimestamp = now - position.inMilliseconds;
    final endTimestamp = duration.inMilliseconds > 0 
        ? startTimestamp + duration.inMilliseconds 
        : null;

    // 2. Handle New Track Session
    if (isTrackChanged) {
      // Logic to prevent "reverting" to an old track:
      // In a multi-provider environment, updates might be out of order.
      // We don't have a global sequence, but we can assume that if we are already
      // playing a track, we shouldn't "go back" to a different one unless explicitly told.
      // However, here we just trust the latest 'isTrackChanged' call is the most recent intent.
      
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
  }

  void _sendActivity(MediaItem track, bool isPlaying, int startTimestamp, int? endTimestamp, String largeImageKey) {
    if (!_isInitialized) return;
    
    FlutterDiscordRPC.instance.setActivity(
      activity: RPCActivity(
        state: track.artist ?? 'Unknown Artist',
        details: track.title,
        assets: RPCAssets(
          largeImage: largeImageKey, 
          largeText: track.album ?? 'Resonance',
          smallImage: isPlaying ? 'play_icon' : 'pause_icon',
          smallText: isPlaying ? 'Playing' : 'Paused',
        ),
        timestamps: RPCTimestamps(
          start: startTimestamp,
          end: isPlaying ? endTimestamp : null,
        ),
      ),
    );
  }


  void clearPresence() {
    if (!_isInitialized) return;
    FlutterDiscordRPC.instance.clearActivity();
    _lastTrackId = null;
    _currentAlbumArtKey = 'resonance_logo';
  }

  void dispose() {
    clearPresence();
    FlutterDiscordRPC.instance.dispose();
  }
}
