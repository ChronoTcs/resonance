import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/application/services/maintenance_service.dart';
import '../providers/audio_provider.dart';
import 'playback_restoration_service.dart';
import 'playback_sync_service.dart';
import 'playback_tracking_service.dart';
import 'gapless_prefetch_service.dart';

/// The AudioOrchestrator acts as a "Bootstrapper" or "Glue" (V17.0 SOTA).
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

      // Reset Gapless Lock on track change
      _ref.read(gaplessPrefetchServiceProvider).resetLock();
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
}
