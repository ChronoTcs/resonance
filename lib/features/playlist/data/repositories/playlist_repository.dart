import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/core/data/services/storage_service.dart';

/// Storage key for SharedPreferences
const _playlistsKey = 'user_playlists';

/// Handles persistence of playlist data to local storage.
/// Separates SharedPreferences I/O from business logic (PlaylistNotifier).
class PlaylistRepository {
  final SharedPreferences _prefs;

  PlaylistRepository(this._prefs);

  /// Retrieves the list of playlists from storage
  Future<List<Playlist>> fetchPlaylists() async {
    final jsonString = _prefs.getString(_playlistsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    return await compute(_parsePlaylistJson, jsonString);
  }

  /// Persists the list of playlists to storage
  Future<void> persistPlaylists(List<Playlist> playlists) async {
    try {
      final jsonString = jsonEncode(playlists.map((p) => p.toJson()).toList());
      await _prefs.setString(_playlistsKey, jsonString);
    } catch (e) {
      debugPrint('[PlaylistRepo] Failed to persist playlists: $e');
      rethrow;
    }
  }

  /// Internal logic for JSON parsing in a separate Isolate
  static List<Playlist> _parsePlaylistJson(String jsonString) {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Playlist.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[PlaylistRepo] Isolate: Failed to parse JSON: $e');
      return [];
    }
  }
}

/// Provider to access the Repository
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PlaylistRepository(prefs);
});
