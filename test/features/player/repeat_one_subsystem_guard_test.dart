import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/domain/models/media_item.dart';
import 'package:resonance/features/player/data/models/player_enums.dart';
import 'package:resonance/features/player/application/services/queue_service.dart';

void main() {
  group('Repeat-One (LoopMode.one) Subsystem Guard Tests', () {
    late QueueService queueService;
    final testTracks = List<MediaItem>.generate(
      5,
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

    test('nextTrack preserves active track identity when LoopMode.one is active', () {
      expect(queueService.currentTrack?.id, equals('track_0'));

      // LoopMode.one: nextTrack must point to the same track (track_0)
      queueService.setLoopMode(LoopMode.one);
      expect(queueService.nextTrack?.id, equals('track_0'));

      // When switched back to LoopMode.off, nextTrack points to track_1
      queueService.setLoopMode(LoopMode.off);
      expect(queueService.nextTrack?.id, equals('track_1'));
    });

    test('peekNextTrack preserves active track identity in Repeat One', () {
      final peeked = queueService.peekNextTrack(LoopMode.one, false);
      expect(peeked?.id, equals('track_0'));

      final peekedAll = queueService.peekNextTrack(LoopMode.all, false);
      expect(peekedAll?.id, equals('track_1'));
    });

    test('peekAhead returns active track when LoopMode.one is active, ignoring positive offsets', () {
      queueService.setLoopMode(LoopMode.one);

      expect(queueService.peekAhead(1)?.id, equals('track_0'));
      expect(queueService.peekAhead(2)?.id, equals('track_0'));
      expect(queueService.peekAhead(4)?.id, equals('track_0'));

      // Restoring to none returns actual forward lookahead
      queueService.setLoopMode(LoopMode.off);
      expect(queueService.peekAhead(1)?.id, equals('track_1'));
      expect(queueService.peekAhead(2)?.id, equals('track_2'));
    });

    test('getUpcomingTracks returns only active track in Repeat One', () {
      queueService.setLoopMode(LoopMode.one);

      final upcoming = queueService.getUpcomingTracks(offset: 1, limit: 3);
      expect(upcoming.length, equals(1));
      expect(upcoming.first.id, equals('track_0'));

      // Switching off Repeat One restores full list
      queueService.setLoopMode(LoopMode.off);
      final normalUpcoming = queueService.getUpcomingTracks(offset: 1, limit: 3);
      expect(normalUpcoming.length, equals(3));
      expect(normalUpcoming.map((t) => t.id).toList(), equals(['track_1', 'track_2', 'track_3']));
    });

    test('getNextTrack on track completion retains active track in Repeat One', () {
      final loopedTrack = queueService.getNextTrack(
        LoopMode.one,
        false,
        fromCompletion: true,
      );
      expect(loopedTrack?.id, equals('track_0'));

      final nextSequentialTrack = queueService.getNextTrack(
        LoopMode.off,
        false,
        fromCompletion: true,
      );
      expect(nextSequentialTrack?.id, equals('track_1'));
    });
  });
}
