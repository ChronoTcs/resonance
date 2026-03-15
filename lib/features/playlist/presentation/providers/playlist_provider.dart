import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _playlistsKey = 'user_playlists';

final playlistProvider = AsyncNotifierProvider<PlaylistNotifier, List<Playlist>>(() {
  return PlaylistNotifier();
});

class PlaylistNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_playlistsKey);
    if (jsonString == null) {
      return [];
    }
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Playlist.fromJson(json)).toList();
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
}
