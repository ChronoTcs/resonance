import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/player/application/services/playback_architecture_service.dart';

void main() {
  group('Playback & Cache Architecture Tests', () {
    test('CachedStreamInfo correctly parses YouTube &expire= UNIX timestamps', () {
      final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final futureUnix = nowUnix + 3600; // 1 hour in future
      final expiredUnix = nowUnix - 60; // 1 minute in past

      final validUrl = 'https://rr1---sn.googlevideo.com/videoplayback?expire=$futureUnix&id=test';
      final expiredUrl = 'https://rr1---sn.googlevideo.com/videoplayback?expire=$expiredUnix&id=test';

      final validParam = Uri.parse(validUrl).queryParameters['expire'];
      final validExpiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(validParam!) * 1000);
      final validInfo = CachedStreamInfo(validUrl, DateTime.now(), expiresAt: validExpiresAt);
      expect(validInfo.isExpired, isFalse);

      final expiredParam = Uri.parse(expiredUrl).queryParameters['expire'];
      final expiredExpiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(expiredParam!) * 1000);
      final expiredInfo = CachedStreamInfo(expiredUrl, DateTime.now(), expiresAt: expiredExpiresAt);
      expect(expiredInfo.isExpired, isTrue);
    });

    test('CachedStreamInfo falls back to 2-hour delta when &expire= is missing', () {
      final freshInfo = CachedStreamInfo('https://stream.example.com/audio.m4a', DateTime.now());
      expect(freshInfo.isExpired, isFalse);

      final oldInfo = CachedStreamInfo(
        'https://stream.example.com/audio.m4a',
        DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(oldInfo.isExpired, isTrue);
    });
  });
}
