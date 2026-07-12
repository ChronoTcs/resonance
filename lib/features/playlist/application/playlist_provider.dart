import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/data/repositories/playlist_repository.dart';

final playlistProvider = AsyncNotifierProvider<PlaylistNotifier, PlaylistState>(() {
  return PlaylistNotifier();
});

class PlaylistState {
  final List<Playlist> local;
  final List<Playlist> online; // Renamed conceptually to "Stream" in UI, model uses online
  final bool isLoadingOnline;

  PlaylistState({
    required this.local,
    this.online = const [],
    this.isLoadingOnline = false,
  });

  PlaylistState copyWith({
    List<Playlist>? local,
    List<Playlist>? online,
    bool? isLoadingOnline,
  }) {
    return PlaylistState(
      local: local ?? this.local,
      online: online ?? this.online,
      isLoadingOnline: isLoadingOnline ?? this.isLoadingOnline,
    );
  }
}

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

class PlaylistNotifier extends AsyncNotifier<PlaylistState> {
  @override
  Future<PlaylistState> build() async {
    final repo = ref.watch(playlistRepositoryProvider);
    final allPlaylists = await repo.fetchPlaylists();
    
    final local = allPlaylists.where((p) => p.id.startsWith('loc_')).toList();
    final online = allPlaylists.where((p) => p.id.startsWith('str_')).toList();
    
    return PlaylistState(
      local: local,
      online: online,
    );
  }

  Future<void> _saveState() async {
    if (state.value == null) return;
    final repo = ref.read(playlistRepositoryProvider);
    final allPlaylists = [...state.value!.local, ...state.value!.online];
    await repo.persistPlaylists(allPlaylists);
  }

  Future<void> createPlaylist(String name, {String description = '', bool isStream = false}) async {
    if (state.value == null) return;
    final newPlaylist = Playlist(
      id: '${isStream ? 'str_' : 'loc_'}${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      tracks: [],
    );

    if (isStream) {
      state = AsyncValue.data(state.value!.copyWith(
        online: [...state.value!.online, newPlaylist],
      ));
    } else {
      state = AsyncValue.data(state.value!.copyWith(
        local: [...state.value!.local, newPlaylist],
      ));
    }
    await _saveState();
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (state.value == null) return;

    if (playlistId.startsWith('str_')) {
      final online = List<Playlist>.from(state.value!.online);
      online.removeWhere((p) => p.id == playlistId);
      state = AsyncValue.data(state.value!.copyWith(online: online));
      await _saveState();
      return;
    }

    if (playlistId.startsWith('loc_')) {
      final local = List<Playlist>.from(state.value!.local);
      local.removeWhere((p) => p.id == playlistId);
      state = AsyncValue.data(state.value!.copyWith(local: local));
      await _saveState();
      return;
    }
  }
  
  Future<void> renamePlaylist(String playlistId, String newName) async {
    if (state.value == null) return;

    if (playlistId.startsWith('str_')) {
      final online = List<Playlist>.from(state.value!.online);
      final index = online.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        online[index] = online[index].copyWith(name: newName);
        state = AsyncValue.data(state.value!.copyWith(online: online));
        await _saveState();
      }
      return;
    }

    if (playlistId.startsWith('loc_')) {
      final local = List<Playlist>.from(state.value!.local);
      final index = local.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        local[index] = local[index].copyWith(name: newName);
        state = AsyncValue.data(state.value!.copyWith(local: local));
        await _saveState();
      }
      return;
    }
  }

  Future<void> addTrackToPlaylist(String playlistId, MediaItem track) async {
    await addTracksToPlaylist(playlistId, [track]);
  }

  Future<void> addTracksToPlaylist(String playlistId, List<MediaItem> tracks) async {
    if (state.value == null) return;

    if (playlistId.startsWith('str_')) {
      final online = List<Playlist>.from(state.value!.online);
      final index = online.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        final playlist = online[index];
        final List<MediaItem> newTracks = [];
        
        for (final track in tracks) {
          final trackId = track.id ?? track.path;
          if (!playlist.tracks.any((t) => (t.id ?? t.path) == trackId)) {
            newTracks.add(track);
          }
        }

        if (newTracks.isNotEmpty) {
          final updatedTracks = [...playlist.tracks, ...newTracks];
          online[index] = playlist.copyWith(tracks: updatedTracks);
          state = AsyncValue.data(state.value!.copyWith(online: online));
          await _saveState();
        }
      }
      return;
    }

    if (playlistId.startsWith('loc_')) {
      final local = List<Playlist>.from(state.value!.local);
      final index = local.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        final playlist = local[index];
        final List<MediaItem> newTracks = [];
        
        for (final track in tracks) {
          final trackId = track.id ?? track.path;
          if (!playlist.tracks.any((t) => (t.id ?? t.path) == trackId)) {
            newTracks.add(track);
          }
        }

        if (newTracks.isNotEmpty) {
          final updatedTracks = [...playlist.tracks, ...newTracks];
          local[index] = playlist.copyWith(tracks: updatedTracks);
          state = AsyncValue.data(state.value!.copyWith(local: local));
          await _saveState();
        }
      }
      return;
    }
  }

  bool isTrackInPlaylist(String playlistId, MediaItem track) {
    if (state.value == null) return false;
    
    final allPlaylists = [...state.value!.local, ...state.value!.online];
    final playlist = allPlaylists.firstWhere(
      (p) => p.id == playlistId, 
      orElse: () => throw Exception('Playlist not found'),
    );
    
    final trackId = track.id ?? track.path;
    return playlist.tracks.any((t) => (t.id ?? t.path) == trackId);
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackPathOrId) async {
    if (state.value == null) return;

    if (playlistId.startsWith('str_')) {
      final online = List<Playlist>.from(state.value!.online);
      final index = online.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        final playlist = online[index];
        final updatedTracks = List<MediaItem>.from(playlist.tracks)
          ..removeWhere((t) => (t.id ?? t.path) == trackPathOrId);
        online[index] = playlist.copyWith(tracks: updatedTracks);
        state = AsyncValue.data(state.value!.copyWith(online: online));
        await _saveState();
      }
      return;
    }

    if (playlistId.startsWith('loc_')) {
      final local = List<Playlist>.from(state.value!.local);
      final index = local.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        final playlist = local[index];
        final updatedTracks = List<MediaItem>.from(playlist.tracks)
          ..removeWhere((t) => (t.id ?? t.path) == trackPathOrId);
        local[index] = playlist.copyWith(tracks: updatedTracks);
        state = AsyncValue.data(state.value!.copyWith(local: local));
        await _saveState();
      }
      return;
    }
  }

  Future<String?> exportPlaylist(String playlistId) async {
    if (state.value == null) return null;
    final playlist = state.value!.online.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => throw Exception('Playlist not found'),
    );
    return jsonEncode(playlist.toJson());
  }

  Future<void> importPlaylist(String jsonString) async {
    if (state.value == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final imported = Playlist.fromJson(data);
      
      // Force "str_" prefix to indicate stream playlist type
      String newId = imported.id;
      if (!newId.startsWith('str_')) {
        newId = 'str_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        newId = 'str_${DateTime.now().millisecondsSinceEpoch}_${imported.id.split('_').last}';
      }

      final playlistCopy = imported.copyWith(id: newId);
      state = AsyncValue.data(state.value!.copyWith(
        online: [...state.value!.online, playlistCopy],
      ));
      await _saveState();
    } catch (e) {
      debugPrint('PlaylistNotifier: Failed to import playlist: $e');
      rethrow;
    }
  }

  /// Auto-repair legacy tracks that changed IDs/Paths
  Future<int> repairPlaylists(List<MediaItem> libraryItems) async {
    if (state.isLoading) await future;
    if (state.value == null) return 0;

    final local = List<Playlist>.from(state.value!.local);
    int totalRepaired = 0;

    for (int i = 0; i < local.length; i++) {
      final res = _repairSinglePlaylist(local[i], libraryItems);
      if (res.repairedCount > 0) {
        local[i] = res.playlist;
        totalRepaired += res.repairedCount;
      }
    }

    if (totalRepaired > 0) {
      state = AsyncValue.data(state.value!.copyWith(local: local));
      await _saveState();
    }
    return totalRepaired;
  }

  /// Repair a specific playlist manually
  Future<int> repairPlaylist(String playlistId, List<MediaItem> libraryItems) async {
    if (state.isLoading) await future;
    if (state.value == null) return 0;
    
    final local = List<Playlist>.from(state.value!.local);
    final index = local.indexWhere((p) => p.id == playlistId);
    
    if (index == -1) return 0;
    
    final res = _repairSinglePlaylist(local[index], libraryItems);
    if (res.repairedCount > 0) {
      local[index] = res.playlist;
      state = AsyncValue.data(state.value!.copyWith(local: local));
      await _saveState();
    }
    
    return res.repairedCount;
  }

  /// Internal logic for repairing a single playlist object
  ({Playlist playlist, int repairedCount}) _repairSinglePlaylist(Playlist playlist, List<MediaItem> libraryItems) {
    final List<MediaItem> updatedTracks = [];
    int count = 0;

    for (final track in playlist.tracks) {
      if (!track.path.startsWith('http') && track.title != 'Unknown Title') {
        final file = File(track.path);
        if (!file.existsSync()) {
          try {
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

