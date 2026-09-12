import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/features/explore/application/services/taste_profile_service.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

final windowsJumpListServiceProvider = Provider<WindowsJumpListService>((ref) {
  final service = WindowsJumpListService(ref);
  if (Platform.isWindows) {
    service.initialize();
  }
  return service;
});

/// Service managing Windows 11/10 Jump List integration (ICustomDestinationList COM API).
/// Exposes "Recently Played", "Quick Picks", and quick Tasks to the Windows Search flyout
/// and taskbar context menu.
class WindowsJumpListService {
  final Ref _ref;
  static const MethodChannel _channel = MethodChannel('resonance/jump_list');

  Timer? _debounceTimer;
  bool _isInitialized = false;

  WindowsJumpListService(this._ref);

  void initialize() {
    if (!Platform.isWindows || _isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCommandReceived') {
        final commandLine = call.arguments as String?;
        if (commandLine != null && commandLine.isNotEmpty) {
          debugPrint('[WindowsJumpList] Received command from Windows Shell: $commandLine');
          await handleCommandLine(commandLine);
        }
      }
    });

    // Initial sync
    syncJumpList();
  }

  /// Debounced sync of Jump List categories ("Recently Played" and "Quick Picks").
  void syncJumpList({Duration debounce = const Duration(seconds: 3)}) {
    if (!Platform.isWindows) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      try {
        await _performSync();
      } catch (e) {
        debugPrint('[WindowsJumpList] Failed to sync Jump List: $e');
      }
    });
  }

  Future<void> _performSync() async {
    // 1. Top 4 Recently Played Tracks
    final recentItems = _ref.read(recentlyPlayedProvider).value ?? [];
    final recentPayload = recentItems.take(4).map((track) {
      return {
        'title': track.title.isNotEmpty ? track.title : 'Unknown Title',
        'artist': track.artist ?? '',
        'id': track.id ?? track.path,
      };
    }).toList();

    // 2. Top 4 Quick Picks from Taste Profile
    List<Map<String, String>> quickPicksPayload = [];
    try {
      final quickPickSeeds = await _ref.read(tasteProfileServiceProvider).getQuickPickSeeds(limit: 4);
      quickPicksPayload = quickPickSeeds.map((track) {
        return {
          'title': track.title.isNotEmpty ? track.title : 'Quick Pick',
          'artist': track.artist ?? '',
          'id': track.id ?? track.path,
        };
      }).toList();
    } catch (_) {}

    // Send payload to Windows C++ Runner
    final success = await _channel.invokeMethod<bool>('updateJumpList', {
      'recentlyPlayed': recentPayload,
      'quickPicks': quickPicksPayload,
    });

    if (success == true) {
      debugPrint('[WindowsJumpList] Jump List synced: ${recentPayload.length} recent, ${quickPicksPayload.length} quick picks');
    }
  }

  /// Parses raw command-line string or arguments list and executes corresponding action.
  Future<void> handleCommandLine(String rawCommandLine) async {
    final clean = rawCommandLine.trim();
    if (clean.isEmpty) return;

    // Check for --action=...
    final actionMatch = RegExp(r'--action=([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (actionMatch != null) {
      final action = actionMatch.group(1);
      await _executeAction(action);
      return;
    }

    // Check for --play-track="<id>" or --play-track=<id>
    final trackMatch = RegExp(r'--play-track=[\"\x27]?([^\"\x27\s]+)[\"\x27]?').firstMatch(clean);
    if (trackMatch != null) {
      final trackId = trackMatch.group(1);
      if (trackId != null && trackId.isNotEmpty) {
        await _playTrackById(trackId);
        return;
      }
    }
  }

  Future<void> _executeAction(String? action) async {
    if (action == null) return;

    switch (action) {
      case 'toggle-play':
        _ref.read(audioProvider.notifier).togglePlayPause();
        break;

      case 'next-track':
        _ref.read(audioProvider.notifier).next();
        break;

      case 'liked-songs':
        final playlistState = _ref.read(playlistProvider).value;
        final liked = playlistState?.likedSongs;
        if (liked != null && liked.tracks.isNotEmpty) {
          _ref.read(audioProvider.notifier).playPlaylist(liked.tracks, initialIndex: 0);
        }
        break;

      case 'search':
        _ref.read(mainNavigationProvider.notifier).setIndex(1);
        break;

      default:
        debugPrint('[WindowsJumpList] Unknown action: $action');
    }
  }

  Future<void> _playTrackById(String trackId) async {
    // 1. Search recently played
    List<MediaItem> recent = _ref.read(recentlyPlayedProvider).value ?? [];
    if (recent.isEmpty) {
      try {
        recent = await _ref.read(recentlyPlayedProvider.future);
      } catch (_) {}
    }
    for (final t in recent) {
      if ((t.id ?? t.path) == trackId || t.id == trackId || t.path == trackId) {
        await _ref.read(audioProvider.notifier).playTrack(t);
        return;
      }
    }

    // 2. Search library tracks
    final libraryTracks = _ref.read(libraryProvider).allMedia;
    for (final t in libraryTracks) {
      if ((t.id ?? t.path) == trackId || t.id == trackId || t.path == trackId) {
        await _ref.read(audioProvider.notifier).playTrack(t);
        return;
      }
    }

    // 3. Search all playlists
    final playlists = _ref.read(playlistProvider).value?.playlists ?? [];
    for (final p in playlists) {
      for (final t in p.tracks) {
        if ((t.id ?? t.path) == trackId || t.id == trackId || t.path == trackId) {
          await _ref.read(audioProvider.notifier).playTrack(t);
          return;
        }
      }
    }

    // 4. If not found in local cache/lists, treat as online YouTube track
    final onlineTrack = MediaItem(
      id: trackId,
      path: trackId,
      title: 'Playing from Windows Search',
      type: 'audio',
    );
    await _ref.read(audioProvider.notifier).playTrack(onlineTrack);
  }
}
