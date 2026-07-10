import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/core/data/services/storage_service.dart';

/// Key penyimpanan untuk SharedPreferences
const _playlistsKey = 'user_playlists';

/// [PlaylistRepository]
/// Tanggung jawab: Menangani persistensi data playlist ke penyimpanan lokal.
/// Memisahkan I/O SharedPreferences dari logika bisnis (PlaylistNotifier).
class PlaylistRepository {
  final SharedPreferences _prefs;

  PlaylistRepository(this._prefs);

  /// Mengambil daftar playlist dari penyimpanan
  Future<List<Playlist>> fetchPlaylists() async {
    final jsonString = _prefs.getString(_playlistsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    // [SOTA] Gunakan compute untuk parsing JSON agar UI tetap responsif
    return await compute(_parsePlaylistJson, jsonString);
  }

  /// Menyimpan daftar playlist ke penyimpanan
  Future<void> persistPlaylists(List<Playlist> playlists) async {
    try {
      final jsonString = jsonEncode(playlists.map((p) => p.toJson()).toList());
      await _prefs.setString(_playlistsKey, jsonString);
    } catch (e) {
      debugPrint('PlaylistRepository: Failed to persist playlists: $e');
      rethrow;
    }
  }

  /// Logic internal untuk parsing JSON di Isolate terpisah
  static List<Playlist> _parsePlaylistJson(String jsonString) {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Playlist.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Playlist Isolate: Failed to parse JSON: $e');
      return [];
    }
  }
}

/// Provider untuk mengakses Repository
/// Menggunakan sharedPreferencesProvider (asumsi sudah ada di core)
/// Jika belum ada, pastikan inisialisasi dilakukan di main.dart
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  // Mengambil SharedPreferences dari provider global
  final prefs = ref.watch(sharedPreferencesProvider);
  return PlaylistRepository(prefs);
});

