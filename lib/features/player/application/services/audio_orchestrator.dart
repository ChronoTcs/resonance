import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/application/services/maintenance_service.dart';
import '../../../explore/data/repositories/youtube_search_repository.dart';
import '../../../library/data/models/media_item.dart';
import '../providers/audio_provider.dart';
import 'playback_restoration_service.dart';
import 'playback_sync_service.dart';
import 'playback_tracking_service.dart';
import 'gapless_prefetch_service.dart';
import 'sponsor_block_service.dart';

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

  // [Radio spam guard] Minimum tracks remaining before we refill
  static const int _radioRefillThreshold = 8;
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
      }

      // Reset Gapless Lock on track change
      _ref.read(gaplessPrefetchServiceProvider).resetLock();

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
      //   1. Only when queue has ≤ _radioRefillThreshold tracks left ahead.
      //   2. Cooldown: minimum 60s between fetches.
      // This prevents cascading — radio tracks are also isStreaming, so
      // without the threshold guard every radio track would re-trigger.
      if (next != null && next.isStreaming) {
        final seedId = next.id ?? next.path;
        if (seedId.isNotEmpty) {
          final audioState = _ref.read(audioProvider);
          final remaining =
              audioState.queue.length - audioState.currentIndex - 1;
          final now = DateTime.now();
          // Always bypass cooldown if the remaining queue is empty (meaning a new seed track was manually played)
          final isManualSeedPlay = remaining <= 0;
          final cooldownPassed = isManualSeedPlay ||
              _lastRadioFetch == null ||
              now.difference(_lastRadioFetch!) > _radioCooldown;

          if (remaining <= _radioRefillThreshold && cooldownPassed) {
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
    _ref.listen(audioProvider.select((s) => s.position), (prev, next) {
      final state = _ref.read(audioProvider);
      if (state.duration > Duration.zero && state.duration.inSeconds > 20) {
        final remaining = state.duration - next;
        if (remaining.inSeconds <= 15 && remaining.inSeconds > 0) {
          _ref.read(gaplessPrefetchServiceProvider).proactiveFetch();
        }
      }
    });
  }

  /// Async radio fetch — fire-and-forget, never throws.
  /// Deduplicates against current queue before appending.
  Future<void> _fetchAndAppendRadio(String videoId) async {
    try {
      final repo = _ref.read(youtubeSearchRepositoryProvider);
      final recs = await repo.getRadioRecommendations(videoId);
      if (recs.isEmpty) return;

      final notifier = _ref.read(audioProvider.notifier);
      final existingIds = _ref.read(audioProvider).queue
          .map((t) => t.id ?? t.path)
          .toSet();

      // ponytail: batch-append to fire _updateNextTrack once, not once per track
      final newTracks = <MediaItem>[];
      for (final track in recs) {
        final id = track.id ?? track.path;
        if (!existingIds.contains(id)) {
          newTracks.add(track);
          existingIds.add(id); // prevent duplicate within the same batch
        }
      }
      if (newTracks.isNotEmpty) {
        notifier.addTracksToQueue(newTracks);
      }
    } catch (_) {}
  }
}
