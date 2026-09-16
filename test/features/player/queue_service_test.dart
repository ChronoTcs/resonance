import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/services/queue_service.dart';
import 'package:resonance/features/player/data/models/player_enums.dart';

void main() {
  late QueueService queueService;
  late List<MediaItem> mockQueue;

  setUp(() {
    queueService = QueueService();
    mockQueue = [
      MediaItem(id: '1', title: 'Track A', path: 'path1', type: 'audio'),
      MediaItem(id: '2', title: 'Track B', path: 'path2', type: 'audio'),
      MediaItem(id: '3', title: 'Track C', path: 'path3', type: 'audio'),
      MediaItem(id: '4', title: 'Track Z', path: 'pathZ', type: 'audio'), // Alphabetically last
    ];
    queueService.setQueue(mockQueue, initialIndex: 0);
  });

  group('QueueService Shuffle Logic', () {
    test('Shuffle respects LoopMode.off and stops at the end', () {
      queueService.setShuffle(true);
      queueService.setLoopMode(LoopMode.off);

      // Play through all tracks in shuffle queue
      for (int i = 0; i < mockQueue.length - 1; i++) {
        final next = queueService.getNextTrack(LoopMode.off, true, fromCompletion: true);
        expect(next, isNotNull);
      }

      // The next one should be null because LoopMode.off is set
      final lastNext = queueService.getNextTrack(LoopMode.off, true, fromCompletion: true);
      expect(lastNext, isNull, reason: 'Should return null after all shuffled tracks are played once with LoopMode.off');
    });

    test('Shuffle respects LoopMode.all and regenerates queue', () {
      queueService.setShuffle(true);
      queueService.setLoopMode(LoopMode.all);

      // Play through all tracks + 1
      for (int i = 0; i < mockQueue.length; i++) {
        final next = queueService.getNextTrack(LoopMode.all, true, fromCompletion: true);
        expect(next, isNotNull);
      }

      // Should still be not null because LoopMode.all is set
      final cycleNext = queueService.getNextTrack(LoopMode.all, true, fromCompletion: true);
      expect(cycleNext, isNotNull, reason: 'Should continue and regenerate queue with LoopMode.all');
    });

    test('Peek next track matches getNextTrack logic', () {
       queueService.setShuffle(true);
       queueService.setLoopMode(LoopMode.off);
       
       // Play until the last song in shuffle
       for (int i = 0; i < mockQueue.length - 1; i++) {
         queueService.getNextTrack(LoopMode.off, true, fromCompletion: true);
       }
       
       // Now we are at the last song of the shuffle queue.
       // Peek should return null if LoopMode.off
       final peeked = queueService.peekNextTrack(LoopMode.off, true);
       expect(peeked, isNull, reason: 'Peek should return null at the end of shuffle queue if LoopMode.off');
    });

    test('appendTracks integrates newly appended stream radio tracks into active shuffle queue', () {
      // Simulate user playing a single track from Home or Explore with Shuffle ON
      final singleTrackService = QueueService();
      final initialSong = MediaItem(id: 'seed1', title: 'Seed Song', path: 'seed1', type: 'audio');
      singleTrackService.setQueue([initialSong], initialIndex: 0);
      singleTrackService.setShuffle(true);
      singleTrackService.setLoopMode(LoopMode.off);

      // Before radio tracks arrive, peekNextTrack is null
      expect(singleTrackService.peekNextTrack(LoopMode.off, true), isNull);

      // AudioOrchestrator fetches radio and appends 4 new tracks
      final radioTracks = [
        MediaItem(id: 'rec1', title: 'Rec 1', path: 'rec1', type: 'audio'),
        MediaItem(id: 'rec2', title: 'Rec 2', path: 'rec2', type: 'audio'),
        MediaItem(id: 'rec3', title: 'Rec 3', path: 'rec3', type: 'audio'),
        MediaItem(id: 'rec4', title: 'Rec 4', path: 'rec4', type: 'audio'),
      ];
      singleTrackService.appendTracks(radioTracks);

      // Verify queue length is now 5
      expect(singleTrackService.queue.length, equals(5));

      // After appendTracks, peekNextTrack MUST NOT be null!
      final upcoming = singleTrackService.peekNextTrack(LoopMode.off, true);
      expect(upcoming, isNotNull);
      expect(['rec1', 'rec2', 'rec3', 'rec4'].contains(upcoming?.id), isTrue);

      // Advance through all 4 radio tracks
      final playedIds = <String>{initialSong.id!};
      for (int i = 0; i < 4; i++) {
        final next = singleTrackService.getNextTrack(LoopMode.off, true, fromCompletion: true);
        expect(next, isNotNull);
        playedIds.add(next!.id!);
      }

      // All 5 unique tracks must have been played in shuffle
      expect(playedIds.length, equals(5));

      // Reached the end with LoopMode.off
      expect(singleTrackService.getNextTrack(LoopMode.off, true, fromCompletion: true), isNull);
    });

    test('appendTrack integrates single incoming track into active shuffle queue', () {
      final singleService = QueueService();
      final songA = MediaItem(id: 'a', title: 'A', path: 'a', type: 'audio');
      singleService.setQueue([songA], initialIndex: 0);
      singleService.setShuffle(true);

      expect(singleService.peekNextTrack(LoopMode.off, true), isNull);

      final songB = MediaItem(id: 'b', title: 'B', path: 'b', type: 'audio');
      singleService.appendTrack(songB);

      expect(singleService.queue.length, equals(2));
      final next = singleService.getNextTrack(LoopMode.off, true);
      expect(next?.id, equals('b'));
    });
  });
}
