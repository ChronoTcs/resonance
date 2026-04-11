import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/services/data_usage_service.dart';
import '../providers/audio_provider.dart';

final playbackTrackingServiceProvider = Provider<PlaybackTrackingService>((ref) {
  final service = PlaybackTrackingService(ref);
  ref.onDispose(() => service.stopTracking());
  return service;
});

class PlaybackTrackingService {
  final Ref _ref;
  Timer? _usageTimer;
  int _lastBytesRead = 0;

  PlaybackTrackingService(this._ref);

  void startTracking() {
    _usageTimer?.cancel();
    _lastBytesRead = 0;
    _usageTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final audioState = _ref.read(audioProvider);
      if (!audioState.isPlaying) return;

      final player = _ref.read(audioProvider.notifier).player;
      try {
        final bytes = await (player.platform as dynamic).getProperty('bytes-read');
        if (bytes != null && (bytes is int || bytes is double)) {
          final delta = bytes.toInt() - _lastBytesRead;
          if (delta > 0) {
            _ref.read(dataUsageServiceProvider).addBytes(delta);
            _lastBytesRead = bytes.toInt();
          }
        }
      } catch (_) {}
    });
  }

  void stopTracking() {
    _usageTimer?.cancel();
    _usageTimer = null;
    _lastBytesRead = 0;
  }
}
