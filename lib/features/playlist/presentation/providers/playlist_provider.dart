import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _playlistsKey = 'user_playlists';

final playlistProvider = AsyncNotifierProvider<PlaylistNotifier, List<Playlist>>(() {
  return PlaylistNotifier();
});

class SelectedPlaylistIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSelectedId(String? id) {
    state = id;
  }
}

final selectedPlaylistIdProvider = NotifierProvider<SelectedPlaylistIdNotifier, String?>(() {
  return SelectedPlaylistIdNotifier();
});

class PlaylistNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_playlistsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    // Use compute for JSON parsing to avoid blocking UI thread
    return await compute(_parsePlaylistJson, jsonString);
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.value?.map((p) => p.toJson()).toList() ?? []);
    await prefs.setString(_playlistsKey, jsonString);
  }

  Future<void> createPlaylist(String name, {String description = ''}) async {
    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      tracks: [],
    );

    state = AsyncValue.data([...state.value ?? [], newPlaylist]);
    await _saveState();
  }

  Future<void> deletePlaylist(String playlistId) async {
    final currentPlaylists = List<Playlist>.from(state.value ?? []);
    currentPlaylists.removeWhere((p) => p.id == playlistId);
    
    state = AsyncValue.data(currentPlaylists);
    await _saveState();
  }
  
  Future<void> renamePlaylist(String playlistId, String newName) async {
    final currentPlaylists = List<Playlist>.from(state.value ?? []);
    final index = currentPlaylists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      currentPlaylists[index] = currentPlaylists[index].copyWith(name: newName);
      state = AsyncValue.data(currentPlaylists);
      await _saveState();
    }
  }

  Future<void> addTrackToPlaylist(String playlistId, MediaItem track) async {
    await addTracksToPlaylist(playlistId, [track]);
  }

  Future<void> addTracksToPlaylist(String playlistId, List<MediaItem> tracks) async {
    final currentPlaylists = List<Playlist>.from(state.value ?? []);
    final index = currentPlaylists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      final playlist = currentPlaylists[index];
      final List<MediaItem> newTracks = [];
      
      for (final track in tracks) {
        final trackId = track.id ?? track.path;
        if (!playlist.tracks.any((t) => (t.id ?? t.path) == trackId)) {
          newTracks.add(track);
        }
      }

      if (newTracks.isNotEmpty) {
        final updatedTracks = [...playlist.tracks, ...newTracks];
        currentPlaylists[index] = playlist.copyWith(tracks: updatedTracks);
        
        state = AsyncValue.data(currentPlaylists);
        await _saveState();
      }
    }
  }

  bool isTrackInPlaylist(String playlistId, MediaItem track) {
    if (state.value == null) return false;
    final playlist = state.value!.firstWhere((p) => p.id == playlistId, orElse: () => throw Exception('Playlist not found'));
    final trackId = track.id ?? track.path;
    return playlist.tracks.any((t) => (t.id ?? t.path) == trackId);
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackPathOrId) async {
    final currentPlaylists = List<Playlist>.from(state.value ?? []);
    final index = currentPlaylists.indexWhere((p) => p.id == playlistId);
    
    if (index != -1) {
      final playlist = currentPlaylists[index];
      final updatedTracks = List<MediaItem>.from(playlist.tracks)
        ..removeWhere((t) => (t.id ?? t.path) == trackPathOrId);
      currentPlaylists[index] = playlist.copyWith(tracks: updatedTracks);
      
      state = AsyncValue.data(currentPlaylists);
      await _saveState();
    }
  }

  /// Auto-repair legacy tracks that changed IDs/Paths
  Future<int> repairPlaylists(List<MediaItem> libraryItems) async {
    if (state.isLoading) await future;
    final currentPlaylists = List<Playlist>.from(state.value ?? []);
    int totalRepaired = 0;

    for (int i = 0; i < currentPlaylists.length; i++) {
      final res = _repairSinglePlaylist(currentPlaylists[i], libraryItems);
      if (res.repairedCount > 0) {
        currentPlaylists[i] = res.playlist;
        totalRepaired += res.repairedCount;
      }
    }

    if (totalRepaired > 0) {
      state = AsyncValue.data(currentPlaylists);
      await _saveState();
    }
    return totalRepaired;
  }

  /// Repair a specific playlist manually
  Future<int> repairPlaylist(String playlistId, List<MediaItem> libraryItems) async {
    if (state.isLoading) await future;
    final currentPlaylists = List<Playlist>.from(state.value ?? []);
    final index = currentPlaylists.indexWhere((p) => p.id == playlistId);
    
    if (index == -1) return 0;
    
    final res = _repairSinglePlaylist(currentPlaylists[index], libraryItems);
    if (res.repairedCount > 0) {
      currentPlaylists[index] = res.playlist;
      state = AsyncValue.data(currentPlaylists);
      await _saveState();
    }
    
    return res.repairedCount;
  }

  /// Internal logic for repairing a single playlist object
  ({Playlist playlist, int repairedCount}) _repairSinglePlaylist(Playlist playlist, List<MediaItem> libraryItems) {
    final List<MediaItem> updatedTracks = [];
    int count = 0;

    for (final track in playlist.tracks) {
      // If it's an online track or the local file still exists, keep it
      if (!track.path.startsWith('http') && track.title != 'Unknown Title') {
        final file = File(track.path);
        if (!file.existsSync()) {
          try {
            // Heuristic match: Title + Artist (normalized)
            final trackTitleLower = track.title.trim().toLowerCase();
            final trackArtistLower = (track.artist ?? 'Unknown Artist').trim().toLowerCase();

            final newMatch = libraryItems.firstWhere((libItem) {
              final libTitleLower = libItem.title.trim().toLowerCase();
              final libArtistLower = (libItem.artist ?? 'Unknown Artist').trim().toLowerCase();
              
              return libTitleLower == trackTitleLower && 
                     (libArtistLower == trackArtistLower || trackArtistLower == 'unknown artist');
            });

            updatedTracks.add(newMatch);
            count++;
            debugPrint('Playlist Repair: Resolved "${track.title}" -> ${newMatch.path}');
            continue;
          } catch (_) {}
        }
      }
      updatedTracks.add(track);
    }

    return (playlist: playlist.copyWith(tracks: updatedTracks), repairedCount: count);
  }
}

/// Isolate-safe JSON parser for Playlists
List<Playlist> _parsePlaylistJson(String jsonString) {
  try {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Playlist.fromJson(json)).toList();
  } catch (e) {
    print('Playlist Isolate: Failed to parse JSON: $e');
    return [];
  }
}
