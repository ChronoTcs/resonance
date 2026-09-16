import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tray/application/tray_service.dart';
import '../../../library/data/models/media_item.dart';
import '../../../lyrics/data/repositories/lyrics_repository.dart';
import 'windows_system_media_service.dart';

final playbackSyncServiceProvider = Provider<PlaybackSyncService>((ref) {
  return PlaybackSyncService(ref);
});

class PlaybackSyncService {
  final Ref _ref;
  PlaybackSyncService(this._ref);

  /// Synchronizes the current playback state with external system controls
  /// (System Tray and Windows SMTC).
  void updateSync(MediaItem? track, bool isPlaying) {
    if (track == null) return;

    // 1. Windows SMTC Sync
    if (Platform.isWindows) {
      final smtc = _ref.read(windowsSystemMediaServiceProvider);
      smtc.updateMetadata(track, isPlaying);
    }

    // 2. Desktop Tray Sync
    if (Platform.isWindows) {
      _ref.read(trayServiceProvider).updateTrayMetadata(track, isPlaying);
    }
  }

  /// Called only on track change (not play/pause toggle) to cache artwork and lyrics.
  /// Separated from updateSync to prevent duplicate downloads on isPlaying toggles.
  Future<void> syncPersistentMetadataOnTrackChange(MediaItem track) async {
    return _syncPersistentMetadata(track);
  }

  /// Used after window restoration from tray to rebuild the Thumbnail Toolbar.
  void forceSyncTaskbar(MediaItem? track, bool isPlaying) {
    if (track == null || !Platform.isWindows) return;
    final smtc = _ref.read(windowsSystemMediaServiceProvider);
    smtc.forceSyncTaskbar(track, isPlaying);
  }

  Future<void> _syncPersistentMetadata(MediaItem track) async {
    if (!track.isStreaming) return;

    try {
      await _ref.read(lyricsRepositoryProvider).getLyrics(track);
    } catch (e) {
      debugPrint('[PlaybackSyncService] Failed to fetch lyrics: $e');
    }
  }
}
