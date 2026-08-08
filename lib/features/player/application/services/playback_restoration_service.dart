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
  Future<void> restoreSession(AudioNotifier notifier) async {
    final persistence = _ref.read(audioPersistenceServiceProvider);
    final s = persistence.loadSettings();

    // We wrap state changes in microtask to prevent Infinite Build loops
    // when triggered during DashboardScreen.initState/build.
    Future.microtask(() async {
      // -- Basic Player Settings --
      notifier.setRestoredSettings(
        volume: s.volume,
        speed: s.speed,
        pitch: s.pitch,
      );

      _ref.read(equalizerControllerProvider.notifier).loadSettings();

      if (s.lastTrackJson != null && s.lastQueueJson != null) {
        try {
          final Map<String, dynamic> trackData = Map<String, dynamic>.from(jsonDecode(s.lastTrackJson!));
          final lastTrack = MediaItem.fromJson(trackData);
          
          final List<MediaItem> fullQueue = s.lastQueueJson!.map((j) {
            final Map<String, dynamic> itemData = Map<String, dynamic>.from(jsonDecode(j));
            return MediaItem.fromJson(itemData);
          }).toList();

          // [Radio bloat guard] Cap restored queue: keep current track + max 20 ahead.
          // Prevents radio-inflated queues (80+ songs) from persisting across sessions.
          // simple slice, no extra state needed.
          const int maxQueueAhead = 20;
          final int savedIndex = s.lastIndex.clamp(0, fullQueue.length - 1);
          final int endIdx = (savedIndex + maxQueueAhead + 1).clamp(0, fullQueue.length);
          final List<MediaItem> lastQueue = fullQueue.sublist(savedIndex, endIdx);
          final int restoredIndex = 0; // current track is now always at index 0 after slice

          // 1. Update internal state via Notifier
          notifier.restorePlaybackState(
            track: lastTrack,
            queue: lastQueue,
            index: restoredIndex,
            positionMs: s.lastPositionMs,
          );

          final player = notifier.player;
          final resolver = _ref.read(streamResolutionServiceProvider);

          String playablePath = lastTrack.path;
          final isLocalFile = !lastTrack.isStreaming &&
              (playablePath.contains('/') || playablePath.contains('\\')) &&
              File(playablePath).existsSync();

          if (!isLocalFile) {
            // Streaming track or stale temp path: check stream cache or fetch URL
            try {
              playablePath = await resolver.resolve(lastTrack);
            } catch (e) {
              debugPrint('[PlaybackRestoration] Resolution failed on restore: $e');
            }
          }

          await player.open(resolver.buildMedia(playablePath), play: false);
          
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
