import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/screens/queue_screen.dart';
import 'package:resonance/features/player/presentation/widgets/queue/queue_item_card.dart';
import 'package:resonance/features/player/presentation/widgets/queue/queue_now_playing_card.dart';

class _MockAudioNotifierForQueue extends AudioNotifier {
  final List<MediaItem> _testQueue;
  final int _testIndex;
  int? lastJumpedIndex;
  int? lastRemovedIndex;

  _MockAudioNotifierForQueue(this._testQueue, this._testIndex);

  @override
  AudioState build() {
    return AudioState(
      queue: _testQueue,
      currentIndex: _testIndex,
      currentTrack: (_testIndex >= 0 && _testIndex < _testQueue.length)
          ? _testQueue[_testIndex]
          : null,
      isPlaying: true,
    );
  }

  @override
  Future<void> jumpToQueueIndex(int index) async {
    lastJumpedIndex = index;
    state = state.copyWith(
      currentIndex: index,
      currentTrack: (index >= 0 && index < _testQueue.length) ? _testQueue[index] : null,
    );
  }

  @override
  void removeTrackFromQueue(int index) {
    lastRemovedIndex = index;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late List<MediaItem> testTracks;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    testTracks = List.generate(
      5,
      (i) => MediaItem(
        id: 'track_$i',
        title: 'Song Title $i',
        artist: 'Artist $i',
        album: 'Album $i',
        path: 'https://example.com/audio_$i.mp3',
        type: 'audio',
        albumArt: Uint8List(0),
        duration: const Duration(minutes: 3),
      ),
    );
  });

  group('QueueScreen 3-Tier Architecture Tests', () {
    testWidgets('Renders Previously Played, Now Playing, and Upcoming sections correctly', (tester) async {
      // Index 2: Songs 0 & 1 are previous, Song 2 is now playing, Songs 3 & 4 are upcoming
      final notifier = _MockAudioNotifierForQueue(testTracks, 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: QueueScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Headers
      expect(find.text('PREVIOUSLY PLAYED'), findsOneWidget);
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);

      // Verify Now Playing Card contains Song 2
      expect(find.byType(QueueNowPlayingCard), findsOneWidget);
      expect(find.text('Song Title 2'), findsOneWidget);

      // Verify Previously Played tracks (0 and 1) are rendered
      expect(find.text('Song Title 0'), findsOneWidget);
      expect(find.text('Song Title 1'), findsOneWidget);

      // Verify Upcoming tracks (3 and 4) are rendered
      expect(find.text('Song Title 3'), findsOneWidget);
      expect(find.text('Song Title 4'), findsOneWidget);
    });

    testWidgets('Tapping Previously Played track jumps to that queue index', (tester) async {
      final notifier = _MockAudioNotifierForQueue(testTracks, 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: QueueScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the card for Song Title 0 (previous track at index 0)
      final historyCardFinder = find.widgetWithText(QueueItemCard, 'Song Title 0');
      expect(historyCardFinder, findsOneWidget);

      // Tap Song Title 0
      await tester.tap(historyCardFinder);
      await tester.pumpAndSettle();

      // Verify jumpToQueueIndex was called with index 0
      expect(notifier.lastJumpedIndex, equals(0));
    });

    testWidgets('Toggles Previously Played history visibility on Show/Hide click', (tester) async {
      final notifier = _MockAudioNotifierForQueue(testTracks, 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: QueueScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Since previous list has 2 items (<= 3), it starts expanded with 'Hide'
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Song Title 0'), findsOneWidget);

      // Tap 'Hide' to collapse
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      // Verify now shows 'Show' and previous items are hidden
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Song Title 0'), findsNothing);

      // Tap 'Show' to re-expand
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Song Title 0'), findsOneWidget);
    });

    testWidgets('Renders clean without overflow on compact mobile viewport (360x800)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = _MockAudioNotifierForQueue(testTracks, 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: QueueScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no exceptions or overflows thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(QueueScreen), findsOneWidget);
    });
  });
}
