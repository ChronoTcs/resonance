import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;
import '../../../../core/application/services/network_connectivity_service.dart';
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
    _ref.read(discordRpcServiceProvider).initialize();
  }

  // Token to detect stale high-res upgrade requests after a track change.
  String? _pendingUpgradeTrackKey;

  // Seek detection: last position snapshot (ms) used to identify large jumps.
  int _lastPositionMs = 0;
  // Timestamp when the current track started, used to filter out residual position ticks from the outgoing track.
  int _trackChangedAtMs = 0;
  // Threshold: jumps > 3s while playing = user-initiated seek.
  static const _kSeekThresholdMs = 3000;

  /// Cancels any in-flight high-res artwork/metadata upgrade and clears Discord presence.
  void cancelPendingUpgrades() {
    _pendingUpgradeTrackKey = null;
    _lastUpgradedArtworkUrl = null;
    _lastPositionMs = 0;
    _trackChangedAtMs = 0;
    _lastSyncedPlaying = false;
    _lastSyncedDuration = Duration.zero;
    try {
      _ref.read(discordRpcServiceProvider).clearPresence();
    } catch (_) {}
  }

  // ── Track Changed ──────────────────────────────────────────────────────────

  /// Called once when a new track starts playing.
  /// Synchronizes metadata to all applicable external surfaces.
  Future<void> onTrackChanged(MediaItem track, {required bool isPlaying}) async {
    _lastUpgradedArtworkUrl = null;
    _lastPositionMs = 0; // reset seek detector for new track
    _trackChangedAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastSyncedPlaying = isPlaying;
    _lastSyncedDuration = track.duration ?? Duration.zero;
    final trackKey = '${track.title}-${track.artist}';
    _pendingUpgradeTrackKey = trackKey;

    // Reset Discord state immediately to prevent stale art from previous track bleeding in
    _ref.read(discordRpcServiceProvider).clearTrackState();

    // 1. Immediately sync all surfaces with original track artwork (no delay)
    await Future.wait([
      _syncAudioServiceMediaItem(track),
      _syncWindowsSmtc(track, isPlaying: isPlaying, force: true),
      // Discord: send immediately on track change so auto-advance (gapless) also
      // updates Discord. startTimestamp = now - 0 = now, which correctly anchors
      // the bar at 0:00. Without this, auto-advance never triggers onPlaybackStatusChanged
      // (playing stream stays true), leaving Discord showing the previous track.
      _syncDiscordPresence(
        track,
        position: Duration.zero,
        duration: track.duration ?? Duration.zero,
        isPlaying: isPlaying,
      ),
    ]);

    // 2. Asynchronously upgrade to 1:1 high-res album art without blocking
    _upgradeToHighResArt(track, isPlaying: isPlaying);
  }

  /// Asynchronously fetches 1:1 high-res album art & album metadata from iTunes and upgrades SMTC/AudioService & AudioState.
  Future<void> _upgradeToHighResArt(MediaItem track, {required bool isPlaying}) async {
    // Only skip if we already have a high-res HTTP thumbnail — no need to re-query iTunes.
    if (track.isLocal && track.thumbnailUrl != null && track.thumbnailUrl!.startsWith('http')) {
      return;
    }
    if (!_ref.read(networkConnectivityProvider).isOnline) {
      return;
    }

    final trackKey = '${track.title}-${track.artist}';
    try {
      final res = await _ref.read(discordRpcServiceProvider).resolveArtworkAndMetadata(track);
      final highResUrl = res.artworkUrl;
      final albumName = res.albumName;

      // Guard: abort if track changed while fetching
      if (_pendingUpgradeTrackKey != trackKey) return;

      final songId = track.id ?? track.path;
      final cacheService = _ref.read(mediaCacheServiceProvider);

      final bool needsArtUpgrade = highResUrl != null && highResUrl.isNotEmpty && highResUrl != track.thumbnailUrl && _lastUpgradedArtworkUrl != highResUrl;
      final bool needsAlbumUpgrade = albumName != null && albumName.isNotEmpty && (track.album == null || track.album == 'Unknown Album');

      if (!needsArtUpgrade && !needsAlbumUpgrade) {
        // Fallback: iTunes art unavailable/identical, cache standard track thumbnail once if not cached yet
        final existing = await cacheService.getCachedArtPath(songId);
        if (existing == null && track.thumbnailUrl != null && track.thumbnailUrl!.startsWith('http')) {
          await cacheService.cacheArtwork(songId, track.thumbnailUrl);
        }
        return;
      }

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
      cacheService.saveMetadataForced(songId, upgradedTrack);

      // Cache high-res iTunes image (single download)
      if (needsArtUpgrade) {
        await cacheService.cacheArtwork(songId, highResUrl, forceOverwrite: true);
      } else {
        final existing = await cacheService.getCachedArtPath(songId);
        if (existing == null && track.thumbnailUrl != null && track.thumbnailUrl!.startsWith('http')) {
          await cacheService.cacheArtwork(songId, track.thumbnailUrl);
        }
      }

      if (_pendingUpgradeTrackKey != trackKey) return;
      final audioState = _ref.read(audioProvider);
      final currentPlaying = audioState.isPlaying;
      final currentPos = audioState.position;
      final currentDur = audioState.duration > Duration.zero
          ? audioState.duration
          : (track.duration ?? Duration.zero);

      await Future.wait([
        _syncAudioServiceMediaItem(upgradedTrack),
        _syncWindowsSmtc(upgradedTrack, isPlaying: currentPlaying),
        _syncDiscordPresence(
          upgradedTrack,
          position: currentPos,
          duration: currentDur,
          isPlaying: currentPlaying,
        ),
      ]);
    } catch (_) {
      // If iTunes lookup fails, ensure standard track thumbnail is cached once as fallback
      try {
        final songId = track.id ?? track.path;
        final cacheService = _ref.read(mediaCacheServiceProvider);
        final existing = await cacheService.getCachedArtPath(songId);
        if (existing == null && track.thumbnailUrl != null && track.thumbnailUrl!.startsWith('http')) {
          await cacheService.cacheArtwork(songId, track.thumbnailUrl);
        }
      } catch (_) {}
    }
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

    final sinceTrackChangeMs = DateTime.now().millisecondsSinceEpoch - _trackChangedAtMs;
    final safePosition = (sinceTrackChangeMs < 2500 &&
            _lastPositionMs < 2000 &&
            position.inMilliseconds > _kSeekThresholdMs)
        ? Duration.zero
        : position;

    _lastSyncedPlaying = isPlaying;
    _lastPositionMs = safePosition.inMilliseconds;

    final effectiveDuration = duration > Duration.zero
        ? duration
        : (currentTrack.duration ?? Duration.zero);
    if (effectiveDuration > Duration.zero) {
      _lastSyncedDuration = effectiveDuration;
    }

    final futures = <Future>[
      _syncDiscordPresence(
        currentTrack,
        position: safePosition,
        duration: effectiveDuration,
        isPlaying: isPlaying,
      ),
    ];

    if (Platform.isWindows) {
      futures.add(_ref.read(windowsSystemMediaServiceProvider).updatePlaybackStatus(isPlaying));
    }

    await Future.wait(futures);
  }

  // ── Timeline Changed ───────────────────────────────────────────────────────

  bool _lastSyncedPlaying = false;
  Duration _lastSyncedDuration = Duration.zero;

  /// Called periodically as playback position changes.
  /// Discord RPC is timestamp-driven — it self-advances using the `start`/`end`
  /// epoch seconds sent once on track change or play/pause events. Pushing
  /// position ticks to Discord every 2s is redundant IPC that drains battery
  /// and introduces a race-condition where a stale `isPlaying=true` tick can
  /// reach Discord after pause, keeping the progress bar running on Android.
  ///
  /// Exception: a seek (position jump > 3s while playing) or the initial resolution
  /// of duration (> 0) / transition to playing state must push to Discord.
  Future<void> onPositionChanged({
    required Duration position,
    required Duration duration,
    required MediaItem? currentTrack,
    required bool isPlaying,
  }) async {
    if (currentTrack == null) return;

    final posMs = position.inMilliseconds;
    final sinceTrackChangeMs = DateTime.now().millisecondsSinceEpoch - _trackChangedAtMs;
    if (sinceTrackChangeMs < 2500 && _lastPositionMs < 2000 && posMs > _kSeekThresholdMs) {
      // Ignore residual position tick from the outgoing track before libmpv resets demuxer to 0:00
      return;
    }

    final delta = (posMs - _lastPositionMs).abs();
    _lastPositionMs = posMs;

    final effectiveDuration = duration > Duration.zero
        ? duration
        : (currentTrack.duration ?? Duration.zero);

    // Sync Discord if:
    // 1. User performed seek (> 3s gap)
    // 2. Playback transitioned to playing but Discord hasn't received playing state yet
    // 3. Duration became known (> 0) after having been zero/missing (enables progress bar)
    final needsDurationSync = _lastSyncedDuration == Duration.zero && effectiveDuration > Duration.zero;
    final needsPlayingSync = isPlaying && !_lastSyncedPlaying;
    final isSeek = isPlaying && delta > _kSeekThresholdMs;

    if (isSeek || needsPlayingSync || (isPlaying && needsDurationSync)) {
      _lastSyncedPlaying = isPlaying;
      if (effectiveDuration > Duration.zero) {
        _lastSyncedDuration = effectiveDuration;
      }
      await _syncDiscordPresence(
        currentTrack,
        position: position,
        duration: effectiveDuration,
        isPlaying: isPlaying,
      );
    }

    if (Platform.isWindows) {
      await _ref.read(windowsSystemMediaServiceProvider).updateTimeline(position, effectiveDuration);
    }
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
      } else if (_ref.read(networkConnectivityProvider).isOnline &&
          track.thumbnailUrl != null &&
          track.thumbnailUrl!.isNotEmpty) {
        // 2. Fallback to online HTTP URL only if online
        artUriString = track.thumbnailUrl;
      }

      // Resolve best available positive duration (track -> player state -> existing audioHandler duration)
      final audioHandler = _ref.read(audioHandlerProvider);
      final existingDuration = audioHandler.mediaItem.value?.duration;
      final playerDuration = _ref.read(audioProvider).duration;

      final Duration? effectiveDuration =
          (track.duration != null && track.duration! > Duration.zero)
              ? track.duration
              : (playerDuration > Duration.zero
                  ? playerDuration
                  : ((existingDuration != null && existingDuration > Duration.zero)
                      ? existingDuration
                      : null));

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
