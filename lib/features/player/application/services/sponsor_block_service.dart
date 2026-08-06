import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../library/data/models/media_item.dart';
import '../providers/audio_provider.dart';

class SponsorBlockService {
  final Ref _ref;
  String? _lastFetchedVideoId;

  SponsorBlockService(this._ref);

  /// Queries SponsorBlock API for off-topic/intro segments and applies offset adjustment
  Future<void> autoDetectAndApplyIntroOffset(MediaItem track) async {
    final videoId = track.id ?? track.path;
    if (videoId.isEmpty || !track.isStreaming || videoId.length != 11) return;

    if (_lastFetchedVideoId == videoId) {
      return;
    }
    _lastFetchedVideoId = videoId;

    final url = Uri.parse(
      'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["music_offtopic"]'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> segments = jsonDecode(response.body);
        if (segments.isNotEmpty) {
          // Identify off-topic/skit intro segment (usually starting at 0s)
          double skipStart = 0;
          double skipEnd = 0;

          for (final segment in segments) {
            final segmentRange = segment['segment'] as List<dynamic>?;
            if (segmentRange != null && segmentRange.length == 2) {
              final start = (segmentRange[0] as num).toDouble();
              final end = (segmentRange[1] as num).toDouble();
              // Check if segment starts near the beginning of the video (intro dialogue/skit)
              if (start <= 5.0 && (end - start) > (skipEnd - skipStart)) {
                skipStart = start;
                skipEnd = end;
              }
            }
          }

          final introDurationMs = ((skipEnd - skipStart) * 1000).toInt();
          if (introDurationMs > 1000) {
            // Shifting forward in time: we subtract from adjustedPosition (i.e. delay highlight triggers by intro duration)
            final delayOffset = Duration(milliseconds: -introDurationMs);
            debugPrint('SponsorBlockService: Detected $introDurationMs ms of intro skit. Applying offset: $delayOffset');
            _ref.read(audioProvider.notifier).adjustLyricsOffset(delayOffset);
          }
        }
      }
    } catch (_) {}
  }
}

final sponsorBlockServiceProvider = Provider<SponsorBlockService>((ref) {
  return SponsorBlockService(ref);
});
