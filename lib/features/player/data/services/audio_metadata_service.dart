import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;
import '../../../../core/data/services/discord_rpc_service.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../../../library/data/models/media_item.dart';
import '../../application/audio_handler.dart';
import '../../application/providers/audio_provider.dart';
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
  String? _lastUpgradedArtworkUrl;

  AudioMetadataService(this._ref) {
    // Discord RPC uses desktop IPC socket — not available on Android
    if (!Platform.isAndroid) {
      _ref.read(discordRpcServiceProvider).initialize();
    }
  }

  // Token to detect stale high-res upgrade requests after a track change.
  String? _pendingUpgradeTrackKey;

  // ── Track Changed ──────────────────────────────────────────────────────────

  /// Called once when a new track starts playing.
  /// Synchronizes metadata to all applicable external surfaces.
  Future<void> onTrackChanged(MediaItem track, {required bool isPlaying}) async {
    _lastUpgradedArtworkUrl = null;
    final trackKey = '${track.title}-${track.artist}';
    _pendingUpgradeTrackKey = trackKey;

    // Reset Discord state immediately to prevent stale art from previous track bleeding in (Bug 2 fix)
    _ref.read(discordRpcServiceProvider).clearTrackState();

    // 1. Immediately sync all surfaces with original track artwork (no delay)
    await Future.wait([
      _syncAudioServiceMediaItem(track),
      _syncWindowsSmtc(track, isPlaying: isPlaying, force: true),
      // Discord presence is sent via position/playing stream ticks which carry
      // real position + duration values. Sending Duration.zero here would cause
      // Discord to display 0:00 timestamps, so we skip it.
      // clearTrackState() above already ensured stale art is cleared.
    ]);

    // 2. Asynchronously upgrade to 1:1 high-res album art without blocking
    _upgradeToHighResArt(track, isPlaying: isPlaying);
  }

  /// Asynchronously fetches 1:1 high-res album art & album metadata from iTunes and upgrades SMTC/AudioService & AudioState.
  Future<void> _upgradeToHighResArt(MediaItem track, {required bool isPlaying}) async {
    if (track.isLocal && (track.albumArt != null || (track.thumbnailUrl != null && !track.thumbnailUrl!.startsWith('http')))) {
      return;
    }

    final trackKey = '${track.title}-${track.artist}';
    try {
      final res = await _ref.read(discordRpcServiceProvider).resolveArtworkAndMetadata(track);
      final highResUrl = res.artworkUrl;
      final albumName = res.albumName;

      // Guard: abort if track changed while fetching
      if (_pendingUpgradeTrackKey != trackKey) return;

      final bool needsArtUpgrade = highResUrl != null && highResUrl.isNotEmpty && highResUrl != track.thumbnailUrl && _lastUpgradedArtworkUrl != highResUrl;
      final bool needsAlbumUpgrade = albumName != null && albumName.isNotEmpty && (track.album == null || track.album == 'Unknown Album');

      if (!needsArtUpgrade && !needsAlbumUpgrade) return;

      if (needsArtUpgrade) _lastUpgradedArtworkUrl = highResUrl;

      final upgradedTrack = track.copyWith(
        thumbnailUrl: needsArtUpgrade ? highResUrl : track.thumbnailUrl,
        album: needsAlbumUpgrade ? albumName : track.album,
      );

      // Back-fill into current player state so Track Info card and download system immediately see the album
      final audioNotifier = _ref.read(audioProvider.notifier);
      audioNotifier.updateCurrentTrack(upgradedTrack);

      // Persist enriched album + thumbnailUrl to sidecar JSON so downloads read correct metadata.
      // fire-and-forget — does not block SMTC/AudioService sync below.
      final songId = track.id ?? track.path;
      _ref.read(mediaCacheServiceProvider).saveMetadataForced(songId, upgradedTrack);

      // Force-overwrite stream art cache with high-res iTunes image, replacing the
      // low-res YouTube thumbnail that was cached when the track first started playing.
      if (needsArtUpgrade) {
        await _ref.read(mediaCacheServiceProvider).cacheArtwork(songId, highResUrl, forceOverwrite: true);
      }

      if (_pendingUpgradeTrackKey != trackKey) return;
      await Future.wait([
        _syncAudioServiceMediaItem(upgradedTrack),
        _syncWindowsSmtc(upgradedTrack, isPlaying: isPlaying),
        _syncDiscordPresence(upgradedTrack, position: Duration.zero, duration: track.duration ?? Duration.zero, isPlaying: isPlaying),
      ]);
    } catch (_) {}
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

  /// Sync MediaSession/SMTC notification metadata via audio_service.
  Future<void> _syncAudioServiceMediaItem(MediaItem track) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      final songId = track.id ?? track.path;
      String? artUriString;

      // 1. Check for local cached artwork file first (most reliable & offline on Windows/Android)
      final cachedPath = await _ref.read(mediaCacheServiceProvider).getCachedArtPath(songId);
      if (cachedPath != null && File(cachedPath).existsSync()) {
        artUriString = cachedPath;
      } else if (track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty) {
        // 2. Fallback to online HTTP URL
        artUriString = track.thumbnailUrl;
      }

      // Use real player duration if track.duration is null (common for local files
      // before the player has fully loaded the media).
      final effectiveDuration = track.duration ?? _ref.read(audioProvider).duration;

      final audioHandler = _ref.read(audioHandlerProvider);
      audioHandler.mediaItem.add(
        audio_svc.MediaItem(
          id: songId,
          album: track.album ?? 'Unknown Album',
          title: track.title,
          artist: track.artist ?? 'Unknown Artist',
          duration: effectiveDuration,
          artUri: artUriString != null && artUriString.isNotEmpty
              ? (artUriString.startsWith('http')
                    ? Uri.parse(artUriString)
                    : Uri.file(artUriString))
              : null,
        ),
      );
    } catch (e) {
      debugPrint('[AudioMetadataService] MediaItem sync failed: $e');
    }
  }

  /// Windows: Update Taskbar with track metadata.
  Future<void> _syncWindowsSmtc(MediaItem track, {required bool isPlaying, bool force = false}) async {
    if (!Platform.isWindows) return;
    try {
      await _ref.read(windowsSystemMediaServiceProvider).updateMetadata(track, isPlaying, force: force);
    } catch (e) {
      debugPrint('[AudioMetadataService] SMTC sync failed: $e');
    }
  }

  /// All platforms (where Discord RPC is supported): Update Rich Presence.
  Future<void> _syncDiscordPresence(
    MediaItem track, {
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) async {
    if (Platform.isAndroid) return; // Discord IPC not available on Android
    try {
      final artworkUrl = await _ref.read(discordRpcServiceProvider).updatePresence(
        track,
        position,
        duration,
        isPlaying,
      );

      // If Discord RPC found a better artwork URL (e.g. iTunes), upgrade SMTC too
      if (artworkUrl != null && Platform.isWindows && artworkUrl != _lastUpgradedArtworkUrl) {
        _lastUpgradedArtworkUrl = artworkUrl;
        await _ref.read(windowsSystemMediaServiceProvider).updateMetadata(
          track,
          isPlaying,
          overrideThumbnailUrl: artworkUrl,
        );
        final audioHandler = _ref.read(audioHandlerProvider);
        if (audioHandler.mediaItem.value != null) {
          audioHandler.mediaItem.add(
            audioHandler.mediaItem.value!.copyWith(
              artUri: Uri.parse(artworkUrl),
            ),
          );
        }
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
