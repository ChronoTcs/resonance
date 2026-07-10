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
  });
}
