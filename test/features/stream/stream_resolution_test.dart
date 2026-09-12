import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/stream/domain/models/playback_session.dart';
import 'package:resonance/features/stream/domain/models/po_token_pair.dart';
import 'package:resonance/features/stream/domain/models/stream_resolution_result.dart';

void main() {
  group('StreamResolutionResult', () {
    test('correctly evaluates expiration', () {
      final active = StreamResolutionResult(
        streamUrl: 'https://rr3---sn.googlevideo.com/videoplayback?id=123',
        playbackHeaders: {'User-Agent': 'test-agent'},
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(active.isExpired, isFalse);

      final expired = StreamResolutionResult(
        streamUrl: 'https://rr3---sn.googlevideo.com/videoplayback?id=123',
        playbackHeaders: {'User-Agent': 'test-agent'},
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(expired.isExpired, isTrue);
    });
  });

  group('PlaybackSession', () {
    test('prefers local file path over resolved network stream', () {
      final session = PlaybackSession(
        videoId: 'gDfBzCed95A',
        localFilePath: '/path/to/cache/gDfBzCed95A.m4a',
        resolved: StreamResolutionResult(
          streamUrl: 'https://rr3---sn.googlevideo.com/videoplayback?id=123',
          playbackHeaders: {'User-Agent': 'test-agent'},
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );

      expect(session.isLocal, isTrue);
      expect(session.uri, '/path/to/cache/gDfBzCed95A.m4a');
      expect(session.headers, isEmpty);
    });

    test('serves remote stream headers when not local', () {
      final session = PlaybackSession(
        videoId: 'gDfBzCed95A',
        resolved: StreamResolutionResult(
          streamUrl: 'https://rr3---sn.googlevideo.com/videoplayback?id=123',
          playbackHeaders: {'User-Agent': 'custom-agent', 'Range': 'bytes=0-'},
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );

      expect(session.isLocal, isFalse);
      expect(session.uri, 'https://rr3---sn.googlevideo.com/videoplayback?id=123');
      expect(session.headers['User-Agent'], 'custom-agent');
    });
  });

  group('PoTokenPair', () {
    test('holds player and stream tokens', () {
      const pair = PoTokenPair(
        playerPoToken: 'token_player_1',
        streamPoToken: 'token_stream_2',
      );
      expect(pair.playerPoToken, 'token_player_1');
      expect(pair.streamPoToken, 'token_stream_2');
    });
  });
}
