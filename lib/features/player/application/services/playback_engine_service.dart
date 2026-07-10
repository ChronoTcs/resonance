import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/services/media_cache_service.dart';
import '../services/stream_resolution_service.dart';

class PlaybackEngineService {
  final Ref _ref;
  int _consecutiveErrorCount = 0;
  DateTime? _lastErrorTime;

  PlaybackEngineService(this._ref);

  void configureCache(dynamic player, String? cacheFolderPath) {
    _ref.read(mediaCacheServiceProvider).setCustomPath(cacheFolderPath);
    MpvConfigurator.applyCacheSettings(player, cacheFolderPath);
  }

  bool handlePlaybackError(dynamic error) {
    final errStr = error.toString();
    if (errStr.contains('.lrc')) return false;

    final now = DateTime.now();
    if (_lastErrorTime != null && now.difference(_lastErrorTime!).inSeconds < 5) {
      _consecutiveErrorCount++;
    } else {
      _consecutiveErrorCount = 1;
    }
    _lastErrorTime = now;

    if (_consecutiveErrorCount >= 3) {
      debugPrint('[PlaybackEngineService] CRITICAL: stopping to prevent infinite error loop.');
      _consecutiveErrorCount = 0;
      return true; // Stop playback
    }
    return false; // Proceed to next
  }

  void resetErrorGuard() {
    _consecutiveErrorCount = 0;
  }
}

final playbackEngineServiceProvider = Provider<PlaybackEngineService>((ref) {
  return PlaybackEngineService(ref);
});
