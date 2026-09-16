 import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/overlay_provider.dart';
import '../../../../core/application/services/network_connectivity_service.dart';
import '../../../../core/providers/cached_stream_music_provider.dart';
import '../../../../core/application/services/maintenance_service.dart';
import '../../../explore/data/repositories/youtube_search_repository.dart';
import '../../../home/presentation/providers/recently_played_provider.dart';
import '../../../library/data/models/media_item.dart';
import '../../../stream/platform/windows/windows_jump_list_service.dart';
import '../providers/audio_provider.dart';
import '../../data/models/player_enums.dart';
import 'playback_restoration_service.dart';
import 'playback_sync_service.dart';
import 'playback_tracking_service.dart';
import 'gapless_prefetch_service.dart';
import 'sponsor_block_service.dart';
import '../../../playlist/application/playlist_auto_continue_provider.dart';
import '../../../library/application/blocked_tracks_provider.dart';

/// It decouples orthogonal logic (Sync, Tracking, Maintenance) from the core 
/// AudioNotifier using the Riverpod pattern.
///
/// This provider must be initialized once at app boot (e.g., DashboardScreen).
final audioOrchestratorProvider = Provider<AudioOrchestrator>((ref) {
  final orchestrator = AudioOrchestrator(ref);
  orchestrator.initialize();
  return orchestrator;
});

class AudioOrchestrator {
  final Ref _ref;
  bool _initialized = false;

  // [Radio spam guard] Minimum gap between consecutive radio fetches
  DateTime? _lastRadioFetch;
  static const Duration _radioCooldown = Duration(seconds: 60);

  AudioOrchestrator(this._ref);

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // 1. Initial Maintenance Task
    _ref.read(maintenanceServiceProvider).runDailyCleanup();

    // 2. Initial Restoration Task
    final notifier = _ref.read(audioProvider.notifier);
    _ref.read(playbackRestorationServiceProvider).restoreSession(notifier);

    // 3. Reactive Listeners (The Glue)
    _setupReactiveListeners();
  }

  void _setupReactiveListeners() {
    // --- Tray & SMTC Sync ORCHESTRATION ---
    // Update whenever track changes OR play/pause state changes
    _ref.listen(audioProvider.select((s) => s.currentTrack), (prev, next) {
      final isPlaying = _ref.read(audioProvider).isPlaying;
      _ref.read(playbackSyncServiceProvider).updateSync(next, isPlaying);

      // Artwork + Lyrics: only on track change, not on every play/pause toggle
      if (next != null && next != prev) {
        _ref.read(playbackSyncServiceProvider).syncPersistentMetadataOnTrackChange(next);
        if (Platform.isWindows) {
          _ref.read(windowsJumpListServiceProvider).syncJumpList();
        }
      }

      // Reset Gapless Lock on track change
      _ref.read(gaplessPrefetchServiceProvider).resetLock();

      // T+0s prefetch — resolve N+1 immediately so rapid skips hit RAM cache
      if (next != null && next != prev) {
        _ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
      }

      // SponsorBlock Auto Intro Trimming Offset
      if (next != null && next.isStreaming) {
        final prevId = prev?.id ?? prev?.path;
        final nextId = next.id ?? next.path;
        if (nextId != prevId) {
          _ref.read(sponsorBlockServiceProvider).autoDetectAndApplyIntroOffset(next);
        }
      }

      // [Radio] Fire-and-forget radio recommendation seeding.
      // Guards:
      //   1. Suppressed when LoopMode.all — finite playlists should loop, not expand.
      //   2. If in playlist mode:
      //      - If autoContinue is OFF: never auto-refill radio.
      //      - If autoContinue is ON: only refill when reaching end of playlist (remaining <= 0).
      //   3. If not in playlist mode: refill when remaining <= threshold.
      //   4. Cooldown: minimum 60s between fetches (bypassed if queue is empty).
      if (next != null && next.isStreaming) {
        final seedId = next.id ?? next.path;
        if (seedId.isNotEmpty) {
          final audioState = _ref.read(audioProvider);
          // Suppress radio during loop-all ONLY if in playlist mode or if queue already has multiple tracks (> 1)
          if (audioState.loopMode == LoopMode.all &&
              (audioState.isPlaylistMode || audioState.queue.length > 1)) {
            return;
          }

          if (audioState.isPlaylistMode) {
            final activePlId = audioState.activePlaylistId;
            final isAutoContinue = activePlId != null &&
                _ref
                    .read(playlistAutoContinueProvider.notifier)
                    .isEnabled(activePlId);
            if (!isAutoContinue) {
              return; // strictly play playlist tracks when auto continue is disabled for this playlist
            }
          }

          final windowSize = _ref.read(queueWindowSizeProvider);
          final remaining =
              audioState.queue.length - audioState.currentIndex - 1;
          final threshold = audioState.isPlaylistMode
              ? 0
              : (windowSize <= 2 ? 1 : (windowSize ~/ 2));

          final now = DateTime.now();
          final isManualSeedPlay = remaining <= 0;
          final cooldownPassed = isManualSeedPlay ||
              _lastRadioFetch == null ||
              now.difference(_lastRadioFetch!) > _radioCooldown;

          if (remaining <= threshold && cooldownPassed) {
            _lastRadioFetch = now;
            _fetchAndAppendRadio(seedId);
          }
        }
      }
    });

    _ref.listen(audioProvider.select((s) => s.isPlaying), (prev, next) {
      final currentTrack = _ref.read(audioProvider).currentTrack;
      
      // Update Sync Layer
      _ref.read(playbackSyncServiceProvider).updateSync(currentTrack, next);

      // --- Data Usage Tracking ORCHESTRATION ---
      final tracker = _ref.read(playbackTrackingServiceProvider);
      if (next) {
        tracker.startTracking();
      } else {
        tracker.stopTracking();
      }
    });

    // --- Gapless Pre-fetch ORCHESTRATION ---
    // Edge trigger: fires exactly once when position crosses 5s after track start.
    // prev < 5s && next >= 5s ensures it fires once per track, not on every position tick.
    _ref.listen(audioProvider.select((s) => s.position), (prev, next) {
      final prevSec = prev?.inSeconds ?? 0;
      if (next.inSeconds >= 5 && prevSec < 5) {
        _ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
      }
    });

    if (Platform.isWindows) {
      _ref.listen(recentlyPlayedProvider, (_, _) {
        _ref.read(windowsJumpListServiceProvider).syncJumpList();
      });
    }
  }

  /// Async radio fetch — fire-and-forget, never throws.
  /// Deduplicates against current queue before appending.
  Future<void> _fetchAndAppendRadio(String videoId) async {
    try {
      final isOnline = _ref.read(networkConnectivityProvider).isOnline;
      final windowSize = _ref.read(queueWindowSizeProvider);
      final notifier = _ref.read(audioProvider.notifier);
      final blocked = _ref.read(blockedTracksProvider.notifier);
      final existingIds = _ref
          .read(audioProvider)
          .queue
          .map((t) => t.id ?? t.path)
          .toSet();

      if (!isOnline) {
        // Offline Radio Fallback: query cachedStreamMusicProvider
        final cachedAsync = _ref.read(cachedStreamMusicProvider);
        final cachedTracks = cachedAsync.asData?.value ?? const <MediaItem>[];
        if (cachedTracks.isEmpty) return;

        final newTracks = <MediaItem>[];
        final shuffled = List<MediaItem>.from(cachedTracks)..shuffle();
        for (final track in shuffled) {
          final id = track.id ?? track.path;
          if (!existingIds.contains(id) && !blocked.isBlocked(track.id, path: track.path)) {
            newTracks.add(track);
            existingIds.add(id);
            if (newTracks.length >= windowSize) break;
          }
        }
        if (newTracks.isNotEmpty) {
          notifier.addTracksToQueue(newTracks);
          debugPrint(
            '[AudioOrchestrator] Appended ${newTracks.length} offline cached tracks to radio queue',
          );
        }
        return;
      }

      final repo = _ref.read(youtubeSearchRepositoryProvider);
      final recs = await repo.getRadioRecommendations(videoId, limit: windowSize);
      if (recs.isEmpty) return;

      // batch-append to fire _updateNextTrack once, not once per track
      final newTracks = <MediaItem>[];
      for (final track in recs) {
        final id = track.id ?? track.path;
        if (!existingIds.contains(id) && !blocked.isBlocked(track.id, path: track.path)) {
          newTracks.add(track);
          existingIds.add(id); // prevent duplicate within the same batch
          if (newTracks.length >= windowSize) break;
        }
      }
      if (newTracks.isNotEmpty) {
        notifier.addTracksToQueue(newTracks);
      }
    } catch (_) {}
  }
}
