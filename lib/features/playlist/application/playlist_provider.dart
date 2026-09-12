import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/data/repositories/playlist_repository.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/data/services/media_cache_service.dart';
import 'package:resonance/features/playlist/application/services/playlist_stream_cache_handler.dart';

final playlistProvider = AsyncNotifierProvider<PlaylistNotifier, PlaylistState>(() {
  return PlaylistNotifier();
});

class PlaylistState {
  final List<Playlist> playlists;
  final bool isLoading;

  const PlaylistState({
    required this.playlists,
    this.isLoading = false,
  });

  PlaylistState copyWith({
    List<Playlist>? playlists,
    bool? isLoading,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Lookup by ID across all playlists.
  Playlist? getById(String id) =>
      playlists.where((p) => p.id == id).firstOrNull;

  /// First playlist named "Liked Songs".
  Playlist? get likedSongs =>
      playlists.where((p) => p.name == 'Liked Songs').firstOrNull;

  // ── Backward-compat getters (avoids mass call-site updates in one pass) ──
  List<Playlist> get local =>
      playlists.where((p) => p.id.startsWith('loc_')).toList();
  List<Playlist> get online =>
      playlists.where((p) => p.id.startsWith('str_')).toList();
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
    return PlaylistState(playlists: allPlaylists);
  }

  Future<void> _saveState() async {
    if (state.value == null) return;
    final repo = ref.read(playlistRepositoryProvider);
    await repo.persistPlaylists(state.value!.playlists);

    // Compute pinned stream IDs for the cache eviction guard.
    // Uses MediaCacheService.getSafeFilename so the stored IDs match
    // the actual filenames in stream/audio/.
    final cacheService = ref.read(mediaCacheServiceProvider);
    final pinnedSafeIds = state.value!.playlists
        .expand((pl) => pl.tracks)
        .where((t) => t.isStreaming)
        .map((t) => cacheService.getSafeFilename(t.id ?? t.path))
        .toSet()
        .toList();

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('pinned_stream_ids', jsonEncode(pinnedSafeIds));
  }

  Future<String?> createPlaylist(String name, {String description = ''}) async {
    if (state.value == null) return null;
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final newPlaylist = Playlist(
      id: id,
      name: name,
      description: description,
      tracks: [],
    );
    state = AsyncValue.data(state.value!.copyWith(
      playlists: [...state.value!.playlists, newPlaylist],
    ));
    await _saveState();
    return id;
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (state.value == null) return;
    final updated = List<Playlist>.from(state.value!.playlists)
      ..removeWhere((p) => p.id == playlistId);
    state = AsyncValue.data(state.value!.copyWith(playlists: updated));
    await _saveState();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    if (state.value == null) return;
    final playlists = List<Playlist>.from(state.value!.playlists);
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    playlists[index] = playlists[index].copyWith(name: newName);
    state = AsyncValue.data(state.value!.copyWith(playlists: playlists));
    await _saveState();
  }

  Future<bool> addTrackToPlaylist(String playlistId, MediaItem track) async {
    return await addTracksToPlaylist(playlistId, [track], isExplicitSingle: true);
  }

  Future<bool> addTracksToPlaylist(
    String playlistId,
    List<MediaItem> tracks, {
    bool isExplicitSingle = false,
  }) async {
    if (state.value == null) return false;
    final playlists = List<Playlist>.from(state.value!.playlists);
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = playlists[index];
    final List<MediaItem> newTracks = [];
    for (final track in tracks) {
      final trackId = track.id ?? track.path;
      if (!playlist.tracks.any((t) => (t.id ?? t.path) == trackId)) {
        newTracks.add(track);
      }
    }

    if (newTracks.isNotEmpty) {
      playlists[index] = playlist.copyWith(tracks: [...playlist.tracks, ...newTracks]);
      state = AsyncValue.data(state.value!.copyWith(playlists: playlists));
      await _saveState();
      unawaited(
        ref.read(playlistStreamCacheHandlerProvider).enqueueTracks(
              newTracks,
              playlistId: playlistId,
              isExplicitSingle: isExplicitSingle,
            ),
      );
      return true;
    }
    return false;
  }

  bool isTrackInPlaylist(String playlistId, MediaItem track) {
    if (state.value == null) return false;
    final playlist = state.value!.getById(playlistId);
    if (playlist == null) return false;
    final trackId = track.id ?? track.path;
    return playlist.tracks.any((t) => (t.id ?? t.path) == trackId);
  }

  Future<bool> toggleTrackInPlaylist(String playlistId, MediaItem track) async {
    if (isTrackInPlaylist(playlistId, track)) {
      await removeTrackFromPlaylist(playlistId, track.id ?? track.path);
      return false;
    } else {
      await addTrackToPlaylist(playlistId, track);
      return true;
    }
  }

  Future<String> getOrCreateLikedPlaylist() async {
    if (state.isLoading) await future;
    final existing = state.value?.likedSongs;
    if (existing != null) return existing.id;
    final newId = await createPlaylist('Liked Songs');
    return newId ?? 'pl_liked_songs';
  }

  Future<bool> toggleLike(MediaItem track) async {
    final likedId = await getOrCreateLikedPlaylist();
    return await toggleTrackInPlaylist(likedId, track);
  }

  bool isLiked(MediaItem track) {
    final liked = state.value?.likedSongs;
    if (liked == null) return false;
    final trackId = track.id ?? track.path;
    return liked.tracks.any((t) => (t.id ?? t.path) == trackId);
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackPathOrId) async {
    if (state.value == null) return;
    final playlists = List<Playlist>.from(state.value!.playlists);
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    final playlist = playlists[index];
    final updatedTracks = List<MediaItem>.from(playlist.tracks)
      ..removeWhere((t) => (t.id ?? t.path) == trackPathOrId);
    playlists[index] = playlist.copyWith(tracks: updatedTracks);
    state = AsyncValue.data(state.value!.copyWith(playlists: playlists));
    await _saveState();
  }

  Future<String?> exportPlaylist(String playlistId) async {
    if (state.value == null) return null;
    final playlist = state.value!.getById(playlistId);
    if (playlist == null) throw Exception('Playlist not found: $playlistId');
    return jsonEncode(playlist.toJson());
  }

  Future<void> importPlaylist(String jsonString) async {
    if (state.value == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      if (!data.containsKey('id') || !data.containsKey('name') || !data.containsKey('tracks')) {
        throw const FormatException('Invalid playlist JSON format. Missing required fields.');
      }
      final imported = Playlist.fromJson(data);
      // Assign a fresh prefix-agnostic ID to avoid collisions
      final newId = 'pl_${DateTime.now().millisecondsSinceEpoch}_import';
      final playlistCopy = imported.copyWith(id: newId);
      state = AsyncValue.data(state.value!.copyWith(
        playlists: [...state.value!.playlists, playlistCopy],
      ));
      await _saveState();
      unawaited(
        ref.read(playlistStreamCacheHandlerProvider).enqueueTracks(
              playlistCopy.tracks,
              playlistId: newId,
              isExplicitSingle: false,
            ),
      );
    } catch (e) {
      debugPrint('[PlaylistNotifier] Failed to import playlist: $e');
      rethrow;
    }
  }

  /// Auto-repair legacy tracks that changed IDs/Paths — covers ALL playlists.
  Future<int> repairPlaylists(List<MediaItem> libraryItems) async {
    if (state.isLoading) await future;
    if (state.value == null) return 0;

    final playlists = List<Playlist>.from(state.value!.playlists);
    int totalRepaired = 0;

    for (int i = 0; i < playlists.length; i++) {
      final res = _repairSinglePlaylist(playlists[i], libraryItems);
      if (res.repairedCount > 0) {
        playlists[i] = res.playlist;
        totalRepaired += res.repairedCount;
      }
    }

    if (totalRepaired > 0) {
      state = AsyncValue.data(state.value!.copyWith(playlists: playlists));
      await _saveState();
    }
    return totalRepaired;
  }

  /// Repair a specific playlist manually.
  Future<int> repairPlaylist(String playlistId, List<MediaItem> libraryItems) async {
    if (state.isLoading) await future;
    if (state.value == null) return 0;

    final playlists = List<Playlist>.from(state.value!.playlists);
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return 0;

    final res = _repairSinglePlaylist(playlists[index], libraryItems);
    if (res.repairedCount > 0) {
      playlists[index] = res.playlist;
      state = AsyncValue.data(state.value!.copyWith(playlists: playlists));
      await _saveState();
    }
    return res.repairedCount;
  }

  /// Internal logic for repairing a single playlist object.
  ({Playlist playlist, int repairedCount}) _repairSinglePlaylist(
      Playlist playlist, List<MediaItem> libraryItems) {
    final List<MediaItem> updatedTracks = [];
    int count = 0;

    for (final track in playlist.tracks) {
      // Skip streaming tracks — their paths are YouTube video IDs, not file paths
      if (track.path.startsWith('http') || track.isStreaming) {
        updatedTracks.add(track);
        continue;
      }
      if (track.title != 'Unknown Title') {
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
            debugPrint('[PlaylistNotifier] Playlist Repair: Resolved "${track.title}" -> ${newMatch.path}');
            continue;
          } catch (_) {}
        }
      }
      updatedTracks.add(track);
    }

    return (playlist: playlist.copyWith(tracks: updatedTracks), repairedCount: count);
  }
}
