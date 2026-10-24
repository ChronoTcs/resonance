import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:resonance/features/player/application/services/queue_service.dart';

void main() {
  group('QueueService peekAhead & getUpcomingTracks Tests', () {
    late QueueService queueService;
    final testTracks = List<MediaItem>.generate(
      6,
      (i) => MediaItem(
        id: 'track_$i',
        title: 'Song $i',
        artist: 'Artist $i',
        path: 'http://example.com/song$i.m4a',
        type: 'audio',
      ),
    );

    setUp(() {
      queueService = QueueService();
      queueService.setQueue(testTracks, initialIndex: 0);
    });

    test('peekAhead returns correct sequential track when shuffle is disabled', () {
      expect(queueService.peekAhead(1)?.id, equals('track_1'));
      expect(queueService.peekAhead(2)?.id, equals('track_2'));
      expect(queueService.peekAhead(5)?.id, equals('track_5'));
      expect(queueService.peekAhead(6), isNull);
    });

    test('getUpcomingTracks returns ordered sequential tracks when shuffle is disabled', () {
      final upcoming = queueService.getUpcomingTracks(offset: 1);
      expect(upcoming.length, equals(5));
      expect(upcoming.map((t) => t.id).toList(), equals(['track_1', 'track_2', 'track_3', 'track_4', 'track_5']));

      final offset3 = queueService.getUpcomingTracks(offset: 3);
      expect(offset3.length, equals(3));
      expect(offset3.map((t) => t.id).toList(), equals(['track_3', 'track_4', 'track_5']));

      final limited = queueService.getUpcomingTracks(offset: 1, limit: 2);
      expect(limited.length, equals(2));
      expect(limited.map((t) => t.id).toList(), equals(['track_1', 'track_2']));
    });

    test('peekAhead and getUpcomingTracks respect shuffle order when shuffle is enabled', () {
      queueService.setShuffle(true);
      // In shuffle mode, current track (track_0) is anchored at index 0.
      expect(queueService.currentTrack?.id, equals('track_0'));

      final n1 = queueService.peekAhead(1, shuffleEnabled: true);
      final n2 = queueService.peekAhead(2, shuffleEnabled: true);
      expect(n1, isNotNull);
      expect(n2, isNotNull);
      expect(n1?.id, isNot(equals('track_0')));

      final upcoming = queueService.getUpcomingTracks(offset: 1, shuffleEnabled: true);
      expect(upcoming.length, equals(5));
      expect(upcoming.first.id, equals(n1?.id));
      expect(upcoming[1].id, equals(n2?.id));
    });

    test('peekAhead out of bounds returns null safely', () {
      expect(queueService.peekAhead(-5), isNull);
      expect(queueService.peekAhead(100), isNull);
      expect(queueService.peekAhead(100, shuffleEnabled: true), isNull);
    });
  });
}
