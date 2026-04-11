import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;
import '../../../../core/data/services/discord_rpc_service.dart';
import '../../../library/data/models/media_item.dart';
import '../../application/audio_handler.dart';
import '../../application/services/windows_system_media_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

/// Centralizes ALL external metadata synchronization across 3 platforms:
/// - [Android] MediaSession notification bar (via AudioService).
/// - [Windows] System Media Transport Controls (SMTC).
/// - [All]     Discord Rich Presence.
///
/// The AudioNotifier calls this service whenever the track changes or
/// playback status updates. This service does NOT hold player state.
class AudioMetadataService {
  final Ref _ref;

  AudioMetadataService(this._ref) {
    // Auto-initialize Discord RPC asinkron
    _ref.read(discordRpcServiceProvider).initialize();
  }

  // ── Track Changed ──────────────────────────────────────────────────────────

  /// Called once when a new track starts playing.
  /// Synchronizes metadata to all applicable external surfaces.
  Future<void> onTrackChanged(MediaItem track, {required bool isPlaying}) async {
    await Future.wait([
      _syncAndroidMediaSession(track),
      _syncWindowsSmtc(track, isPlaying: isPlaying),
      _syncDiscordPresence(track, position: Duration.zero, duration: track.duration ?? Duration.zero, isPlaying: isPlaying),
    ]);
  }

  // ── Playback Status Changed ────────────────────────────────────────────────

  /// Called when play/pause state changes without a track change.
  Future<void> onPlaybackStatusChanged({
    required MediaItem? currentTrack,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
  }) async {
    if (currentTrack == null) return;

    final futures = <Future>[
      _syncDiscordPresence(currentTrack, position: position, duration: duration, isPlaying: isPlaying),
    ];

    if (Platform.isWindows) {
      futures.add(_ref.read(windowsSystemMediaServiceProvider).updatePlaybackStatus(isPlaying));
    }

    await Future.wait(futures);
  }

  // ── Timeline Changed ───────────────────────────────────────────────────────

  /// Called periodically as playback position changes.
  Future<void> onPositionChanged({
    required Duration position,
    required Duration duration,
    required MediaItem? currentTrack,
    required bool isPlaying,
  }) async {
    if (currentTrack == null) return;

    final futures = <Future>[
      _syncDiscordPresence(currentTrack, position: position, duration: duration, isPlaying: isPlaying),
    ];

    if (Platform.isWindows) {
      futures.add(_ref.read(windowsSystemMediaServiceProvider).updateTimeline(position, duration));
    }

    await Future.wait(futures);
  }

  // ── Platform-Specific Implementations ─────────────────────────────────────

  /// Android: Update MediaSession for lock screen and notification controls.
  Future<void> _syncAndroidMediaSession(MediaItem track) async {
    if (!Platform.isAndroid) return;
    try {
      final audioHandler = _ref.read(audioHandlerProvider);
      audioHandler.mediaItem.add(
        audio_svc.MediaItem(
          id: track.id ?? track.path,
          album: track.album ?? 'Unknown Album',
          title: track.title,
          artist: track.artist ?? 'Unknown Artist',
          duration: track.duration,
          artUri: track.thumbnailUrl != null
              ? (track.thumbnailUrl!.startsWith('http')
                    ? Uri.parse(track.thumbnailUrl!)
                    : Uri.file(track.thumbnailUrl!))
              : null,
        ),
      );
    } catch (e) {
      debugPrint('[AudioMetadataService] Android MediaSession sync failed: $e');
    }
  }

  /// Windows: Update SMTC with track metadata.
  Future<void> _syncWindowsSmtc(MediaItem track, {required bool isPlaying}) async {
    if (!Platform.isWindows) return;
    try {
      await _ref.read(windowsSystemMediaServiceProvider).updateMetadata(track, isPlaying);
    } catch (e) {
      debugPrint('[AudioMetadataService] SMTC sync failed: $e');
    }
  }

  /// All platforms (where Discord RPC is supported): Update Rich Presence.
  /// Also returns the artwork URL found by Discord service, which can be used
  /// to update SMTC with a higher-quality image on Windows.
  Future<void> _syncDiscordPresence(
    MediaItem track, {
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) async {
    try {
      final artworkUrl = await _ref.read(discordRpcServiceProvider).updatePresence(
        track,
        position,
        duration,
        isPlaying,
      );

      // If Discord RPC found a better artwork URL (e.g. iTunes), upgrade SMTC too
      if (artworkUrl != null && Platform.isWindows) {
        await _ref.read(windowsSystemMediaServiceProvider).updateMetadata(
          track,
          isPlaying,
          overrideThumbnailUrl: artworkUrl,
        );
      }
    } catch (e) {
      debugPrint('[AudioMetadataService] Discord RPC sync failed: $e');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final audioMetadataServiceProvider = Provider<AudioMetadataService>((ref) {
  return AudioMetadataService(ref);
});
