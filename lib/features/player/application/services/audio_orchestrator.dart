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
import 'session_history_tracker.dart';
import '../../../explore/application/services/user_taste_profile_service.dart';

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

  // [Anchor Leash & Circuit Breakers]
  MediaItem? _sessionAnchorTrack;
  int _consecutiveFastSkips = 0;
  int _refillCount = 0;

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
      final prevId = prev?.id ?? prev?.path;
      final nextId = next?.id ?? next?.path;
      final isTrackChanged = prevId != nextId;

      final isPlaying = _ref.read(audioProvider).isPlaying;
      _ref.read(playbackSyncServiceProvider).updateSync(next, isPlaying);

      // Artwork + Lyrics: only on actual track change, not on lyrics offset or play/pause toggle
      if (next != null && isTrackChanged) {
        _ref.read(playbackSyncServiceProvider).syncPersistentMetadataOnTrackChange(next);
        if (Platform.isWindows) {
          _ref.read(windowsJumpListServiceProvider).syncJumpList();
        }
      }

      // Track engagement telemetry & Session Ring Buffer
      if (prev != null && isTrackChanged) {
        final notifier = _ref.read(audioProvider.notifier);
        final statePos = _ref.read(audioProvider).position;
        final stateDur = _ref.read(audioProvider).duration;
        final prevPos = notifier.lastTrackFinalPosition > statePos
            ? notifier.lastTrackFinalPosition
            : statePos;
        final prevDur = notifier.lastTrackFinalDuration > Duration.zero
            ? notifier.lastTrackFinalDuration
            : (stateDur > Duration.zero ? stateDur : (prev.duration ?? Duration.zero));

        _ref.read(userTasteProfileServiceProvider).recordEngagement(
          prev,
          position: prevPos,
          duration: prevDur,
        );
        _ref.read(sessionHistoryTrackerProvider).recordPlayed(prev.id ?? prev.path);

        // Fast-Skip Circuit Breaker Check (2 consecutive skips < 15s)
        final isFastSkip = prevPos.inSeconds < 15;
        if (isFastSkip) {
          _consecutiveFastSkips++;
          if (_consecutiveFastSkips >= 2) {
            debugPrint('[AudioOrchestrator] Circuit Breaker: 2 fast-skips detected. Purging drift & re-anchoring.');
            _purgeDriftAndReanchor();
            _consecutiveFastSkips = 0;
          }
        } else if (prevPos.inSeconds >= 30) {
          _consecutiveFastSkips = 0;
        }
      }

      final queueLen = _ref.read(audioProvider).queue.length;
      if (next != null && (queueLen <= 1 || _sessionAnchorTrack == null || isTrackChanged)) {
        if (isTrackChanged || _sessionAnchorTrack == null) {
          _sessionAnchorTrack = next;
          _consecutiveFastSkips = 0;
        }
      }

      // Reset Gapless Lock and proactive fetch on track change
      if (isTrackChanged) {
        _ref.read(gaplessPrefetchServiceProvider).resetLock();
        if (next != null) {
          _ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
        }
      }

      // SponsorBlock Auto Intro Trimming Offset
      if (next != null && next.isStreaming && isTrackChanged) {
        _ref.read(sponsorBlockServiceProvider).autoDetectAndApplyIntroOffset(next);
      }

      // [Radio] Fire-and-forget radio recommendation seeding.
      // Guards:
      //   1. Suppressed when LoopMode.all or LoopMode.one if queue already has tracks (> 1) or in playlist mode.
      //   2. If in playlist mode:
      //      - If autoContinue is OFF: never auto-refill radio.
      //      - If autoContinue is ON: only refill when reaching end of playlist (remaining <= 0).
      //   3. If not in playlist mode: refill when remaining <= threshold.
      //   4. Cooldown: minimum 60s between fetches (bypassed on manual seed play where remaining <= 0).
      final audioState = _ref.read(audioProvider);
      final isManualSeedReplay = !audioState.isPlaylistMode &&
          audioState.queue.length == 1 &&
          audioState.currentIndex == 0;

      if (next != null && next.isStreaming && (isTrackChanged || isManualSeedReplay)) {
        final seedId = next.id ?? next.path;
        if (seedId.isNotEmpty) {
          // Suppress radio during loop-all or loop-one if in playlist mode or if queue already has multiple tracks (> 1)
          if ((audioState.loopMode == LoopMode.all ||
                  audioState.loopMode == LoopMode.one) &&
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

      // Resume proactive prefetch if unpaused or session playback started
      if (next && !(prev ?? false)) {
        if (_ref.read(audioProvider).loopMode != LoopMode.one) {
          _ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
        }
      }
    });

    // --- Gapless Pre-fetch ORCHESTRATION ---
    // Edge trigger: fires exactly once when position crosses 5s after track start.
    // prev < 5s && next >= 5s ensures it fires once per track, not on every position tick.
    _ref.listen(audioProvider.select((s) => s.position), (prev, next) {
      final prevSec = prev?.inSeconds ?? 0;
      if (next.inSeconds >= 5 && prevSec < 5) {
        if (_ref.read(audioProvider).loopMode != LoopMode.one) {
          _ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
        }
      }
    });

    if (Platform.isWindows) {
      _ref.listen(recentlyPlayedProvider, (_, _) {
        _ref.read(windowsJumpListServiceProvider).syncJumpList();
      });
    }
  }

  /// Async radio fetch — fire-and-forget, never throws.
  /// Deduplicates against current queue and session history ring buffer.
  Future<void> _fetchAndAppendRadio(String videoId) async {
    try {
      final isOnline = _ref.read(networkConnectivityProvider).isOnline;
      final windowSize = _ref.read(queueWindowSizeProvider);
      final notifier = _ref.read(audioProvider.notifier);
      final blocked = _ref.read(blockedTracksProvider.notifier);
      final sessionTracker = _ref.read(sessionHistoryTrackerProvider);
      final existingIds = _ref
          .read(audioProvider)
          .queue
          .map((t) => t.id ?? t.path)
          .toSet();

      final combinedExcludeIds = sessionTracker.recentIds.union(existingIds);

      if (!isOnline) {
        // Offline Radio Fallback: query cachedStreamMusicProvider
        final cachedAsync = _ref.read(cachedStreamMusicProvider);
        final cachedTracks = cachedAsync.asData?.value ?? const <MediaItem>[];
        if (cachedTracks.isEmpty) return;

        final newTracks = <MediaItem>[];
        final shuffled = List<MediaItem>.from(cachedTracks)..shuffle();
        for (final track in shuffled) {
          final id = track.id ?? track.path;
          if (!combinedExcludeIds.contains(id) && !blocked.isBlocked(track.id, path: track.path)) {
            newTracks.add(track);
            combinedExcludeIds.add(id);
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

      _refillCount++;
      // [Anchor Leash] Alternating re-centering: every 2nd refill seeds from sessionAnchorTrack
      String effectiveSeedId = videoId;
      if (_refillCount % 2 == 1 && _sessionAnchorTrack != null) {
        final anchorId = _sessionAnchorTrack!.id ?? _sessionAnchorTrack!.path;
        if (anchorId.isNotEmpty && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(anchorId)) {
          effectiveSeedId = anchorId;
          debugPrint('[AudioOrchestrator] Anchor Leash: Re-centering radio seed to $effectiveSeedId');
        }
      }

      final repo = _ref.read(youtubeSearchRepositoryProvider);
      final recs = await repo.getRadioRecommendations(
        effectiveSeedId,
        limit: windowSize,
        excludeIds: combinedExcludeIds,
        enableEntropy: true,
      );
      if (recs.isEmpty) return;

      // batch-append to fire _updateNextTrack once, not once per track
      final newTracks = <MediaItem>[];
      for (final track in recs) {
        final id = track.id ?? track.path;
        if (!combinedExcludeIds.contains(id) && !blocked.isBlocked(track.id, path: track.path)) {
          newTracks.add(track);
          combinedExcludeIds.add(id); // prevent duplicate within the same batch
          if (newTracks.length >= windowSize) break;
        }
      }
      if (newTracks.isNotEmpty) {
        notifier.addTracksToQueue(newTracks);
      }
    } catch (_) {}
  }

  /// Circuit breaker action: purges drifted radio tracks and re-seeds from session anchor.
  void _purgeDriftAndReanchor() {
    final notifier = _ref.read(audioProvider.notifier);
    notifier.clearUpcomingQueue();
    if (_sessionAnchorTrack != null) {
      final anchorId = _sessionAnchorTrack!.id ?? _sessionAnchorTrack!.path;
      if (anchorId.isNotEmpty && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(anchorId)) {
        _fetchAndAppendRadio(anchorId);
      }
    }
  }

  /// Sets or updates the session anchor track.
  void setSessionAnchor(MediaItem track) {
    _sessionAnchorTrack = track;
    _consecutiveFastSkips = 0;
  }
}
