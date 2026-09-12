import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import '../data/models/blocked_track.dart';

const String _kBlockedTracksKey = 'blocked_tracks_list';

class BlockedTracksNotifier extends Notifier<List<BlockedTrack>> {
  Set<String> _blockedIds = {};

  Set<String> get blockedIds => _blockedIds;

  @override
  List<BlockedTrack> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _loadFromPrefs(prefs);
  }

  List<BlockedTrack> _loadFromPrefs(SharedPreferences prefs) {
    try {
      final rawList = prefs.getStringList(_kBlockedTracksKey);
      if (rawList == null || rawList.isEmpty) {
        _blockedIds = {};
        return [];
      }

      final items = <BlockedTrack>[];
      final ids = <String>{};

      for (final raw in rawList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final track = BlockedTrack.fromJson(map);
          items.add(track);
          ids.add(track.id);
        } catch (_) {}
      }

      _blockedIds = ids;
      return items;
    } catch (e) {
      debugPrint('[BlockedTracks] Error loading blocked tracks: $e');
      _blockedIds = {};
      return [];
    }
  }

  /// Fast O(1) lookup to check if a track is blocked.
  bool isBlocked(String? id, {String? path}) {
    if (id != null && _blockedIds.contains(id)) return true;
    if (path != null && _blockedIds.contains(path)) return true;
    return false;
  }

  /// Blocks a track and persists to storage.
  Future<void> blockTrack(MediaItem item) async {
    final trackId = item.id ?? item.path;
    if (trackId.isEmpty || isBlocked(trackId)) return;

    final newBlocked = BlockedTrack(
      id: trackId,
      title: item.title.isNotEmpty ? item.title : 'Unknown Track',
      artist: item.artist,
      thumbnailUrl: item.thumbnailUrl,
      blockedAt: DateTime.now(),
    );

    final updated = [newBlocked, ...state.where((t) => t.id != trackId)];
    state = updated;
    _blockedIds.add(trackId);
    await _saveToPrefs(updated);
  }

  /// Unblocks a track by its identifier.
  Future<void> unblockTrack(String trackId) async {
    if (!isBlocked(trackId)) return;

    final updated = state.where((t) => t.id != trackId).toList();
    state = updated;
    _blockedIds.remove(trackId);
    await _saveToPrefs(updated);
  }

  /// Clears all blocked tracks.
  Future<void> clearAll() async {
    state = [];
    _blockedIds.clear();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kBlockedTracksKey);
  }

  Future<void> _saveToPrefs(List<BlockedTrack> tracks) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final rawList = tracks.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_kBlockedTracksKey, rawList);
    } catch (e) {
      debugPrint('[BlockedTracks] Error saving blocked tracks: $e');
    }
  }
}

final blockedTracksProvider =
    NotifierProvider<BlockedTracksNotifier, List<BlockedTrack>>(
  BlockedTracksNotifier.new,
);
