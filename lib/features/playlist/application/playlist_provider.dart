import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/playlist/data/repositories/playlist_repository.dart';
import 'package:resonance_app/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance_app/features/explore/application/services/youtube_auth_service.dart';

final playlistProvider = AsyncNotifierProvider<PlaylistNotifier, PlaylistState>(() {
  return PlaylistNotifier();
});

class PlaylistState {
  final List<Playlist> local;
  final List<Playlist> online;
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
    final local = await repo.fetchPlaylists();
    
    // Auto-fetch online playlists if logged in (non-blocking)
    if (ref.read(youtubeAuthServiceProvider).isLoggedIn) {
      Future.delayed(const Duration(milliseconds: 500), () => refreshOnlinePlaylists());
    }
    
    return PlaylistState(local: local);
  }

  Future<void> _saveState() async {
    if (state.value == null) return;
    // [GUARDRAIL 2] Persistent Guard: Only save local playlists
    final repo = ref.read(playlistRepositoryProvider);
    await repo.persistPlaylists(state.value!.local);
  }

  Future<void> createPlaylist(String name, {String description = ''}) async {
    if (state.value == null) return;
    final newPlaylist = Playlist(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      tracks: [],
    );

    state = AsyncValue.data(state.value!.copyWith(
      local: [...state.value!.local, newPlaylist],
    ));
    await _saveState();
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (state.value == null) return;

    // Check if it's an online playlist delete (unsupported directly for now, or add implementation)
    if (!playlistId.startsWith('loc_')) {
      debugPrint('PlaylistNotifier: Direct online playlist deletion not yet implemented.');
      return;
    }

    final local = List<Playlist>.from(state.value!.local);
    local.removeWhere((p) => p.id == playlistId);
    
    state = AsyncValue.data(state.value!.copyWith(local: local));
    await _saveState();
  }
  
  Future<void> renamePlaylist(String playlistId, String newName) async {
    if (state.value == null) return;
    final local = List<Playlist>.from(state.value!.local);
    final index = local.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      local[index] = local[index].copyWith(name: newName);
      state = AsyncValue.data(state.value!.copyWith(local: local));
      await _saveState();
    }
  }

  Future<void> addTrackToPlaylist(String playlistId, MediaItem track) async {
    await addTracksToPlaylist(playlistId, [track]);
  }

  Future<void> addTracksToPlaylist(String playlistId, List<MediaItem> tracks) async {
    if (state.value == null) return;

    // --- CASE 1: Online Sync ---
    if (!playlistId.startsWith('loc_')) {
      final repo = ref.read(youtubePlaylistRepositoryProvider);
      for (final track in tracks) {
        if (track.id != null) {
          await repo.editYouTubePlaylist(
            playlistId,
            track.id!,
            isAdd: true,
          );
        }
      }
      refreshOnlinePlaylists(); // Refresh memory state
      return;
    }

    // --- CASE 2: Local Persistence ---
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

    // --- CASE 1: Online Sync (Requires setVideoId) ---
    if (!playlistId.startsWith('loc_')) {
      final playlist = state.value!.online.firstWhere((p) => p.id == playlistId);
      final track = playlist.tracks.firstWhere((t) => (t.id ?? t.path) == trackPathOrId);
      
      if (track.setVideoId != null) {
        final repo = ref.read(youtubePlaylistRepositoryProvider);
        await repo.editYouTubePlaylist(
          playlistId,
          trackPathOrId,
          isAdd: false,
          setVideoId: track.setVideoId,
        );
        refreshOnlinePlaylists();
      }
      return;
    }

    // --- CASE 2: Local Persistence ---
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
  }

  // --- [V20.7 SOTA] ONLINE OPERATIONS ---

  Future<void> refreshOnlinePlaylists() async {
    if (state.value == null) return;
    state = AsyncValue.data(state.value!.copyWith(isLoadingOnline: true));

    try {
      final repo = ref.read(youtubePlaylistRepositoryProvider);
      final explorePlaylists = await repo.fetchMyPlaylists();

      final List<Playlist> online = explorePlaylists.map((ep) => Playlist(
        id: ep.id,
        name: ep.title,
        description: 'YouTube Music Playlist by ${ep.author}',
        tracks: [], // Initially empty, load on demand
      )).toList();

      state = AsyncValue.data(state.value!.copyWith(online: online, isLoadingOnline: false));
    } catch (e) {
      debugPrint('PlaylistNotifier: Online refresh failed: $e');
      state = AsyncValue.data(state.value!.copyWith(isLoadingOnline: false));
    }
  }

  Future<void> loadOnlinePlaylistTracks(String playlistId) async {
    if (state.value == null) return;
    
    final index = state.value!.online.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    try {
      final repo = ref.read(youtubePlaylistRepositoryProvider);
      final items = await repo.fetchFullPlaylistContents(playlistId);

      final List<MediaItem> tracks = items.map((item) => MediaItem(
        id: item.id,
        path: item.url,
        title: item.title,
        artist: item.author,
        thumbnailUrl: item.thumbnailUrl,
        type: 'audio',
        setVideoId: item.setVideoId, // [V20.7 SOTA] Propagate for removals
      )).toList();

      final online = List<Playlist>.from(state.value!.online);
      online[index] = online[index].copyWith(tracks: tracks);

      state = AsyncValue.data(state.value!.copyWith(online: online));
    } catch (e) {
      debugPrint('PlaylistNotifier: Failed to load online tracks: $e');
    }
  }

  Future<void> convertOnlineToLocal(Playlist onlinePlaylist) async {
    if (state.value == null) return;
    
    final newLocalId = 'loc_${DateTime.now().millisecondsSinceEpoch}';
    final localCopy = onlinePlaylist.copyWith(
      id: newLocalId,
      name: '${onlinePlaylist.name} (Imported)',
    );

    state = AsyncValue.data(state.value!.copyWith(
      local: [...state.value!.local, localCopy],
    ));
    await _saveState();
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
