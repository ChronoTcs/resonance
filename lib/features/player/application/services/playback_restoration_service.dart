import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tray/application/tray_service.dart';
import '../../../library/data/models/media_item.dart';
import '../../data/services/audio_persistence_service.dart';
import '../providers/audio_provider.dart';
import '../providers/equalizer_controller.dart';
import 'stream_resolution_service.dart';

final playbackRestorationServiceProvider = Provider<PlaybackRestorationService>((ref) {
  return PlaybackRestorationService(ref);
});

class PlaybackRestorationService {
  final Ref _ref;
  PlaybackRestorationService(this._ref);

  /// Restores the last playback session from persistence.
  /// Follows V16.1 SOTA: Engine Seek Guard and Cold Start Tray Sync.
  Future<void> restoreSession(AudioNotifier notifier) async {
    final persistence = _ref.read(audioPersistenceServiceProvider);
    final s = persistence.loadSettings();

    // -- Restoration Build-Phase Guard (V17.7 SOTA) --
    // We wrap state changes in microtask to prevent Infinite Build loops
    // when triggered during DashboardScreen.initState/build.
    Future.microtask(() async {
      // -- Basic Player Settings --
      notifier.setRestoredSettings(
        volume: s.volume,
        speed: s.speed,
        pitch: s.pitch,
      );

      // -- Equalizer Restoration (V17.5) --
      _ref.read(equalizerControllerProvider.notifier).loadSettings();

      // -- Global Resume Orchestration (V16.1) --
      if (s.lastTrackJson != null && s.lastQueueJson != null) {
        try {
          final Map<String, dynamic> trackData = Map<String, dynamic>.from(jsonDecode(s.lastTrackJson!));
          final lastTrack = MediaItem.fromJson(trackData);
          
          final List<MediaItem> lastQueue = s.lastQueueJson!.map((j) {
            final Map<String, dynamic> itemData = Map<String, dynamic>.from(jsonDecode(j));
            return MediaItem.fromJson(itemData);
          }).toList();
          
          // 1. Update internal state via Notifier
          notifier.restorePlaybackState(
            track: lastTrack,
            queue: lastQueue,
            index: s.lastIndex,
            positionMs: s.lastPositionMs,
          );

          // 2. [SOTA] Engine Seek Guard: Open but don't play yet
          final player = notifier.player;
          final resolver = _ref.read(streamResolutionServiceProvider);
          await player.open(resolver.buildMedia(lastTrack.path), play: false);
          
          // Wait for engine to be ready before seeking
          late StreamSubscription readinessSub;
          readinessSub = player.stream.duration.listen((duration) {
            if (duration > Duration.zero) {
              player.seek(Duration(milliseconds: s.lastPositionMs));
              readinessSub.cancel();
            }
          });

          // 3. [Windows] Cold Start Tray Sync
          if (Platform.isWindows) {
            _ref.read(trayServiceProvider).updateTrayMetadata(lastTrack, false);
          }
        } catch (e) {
          debugPrint('[PlaybackRestoration] Failed to restore playback state: $e');
        }
      }
    });
  }
}
