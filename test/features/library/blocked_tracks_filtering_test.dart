import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/providers/cached_stream_music_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class MockAudioNotifier extends AudioNotifier {
  List<MediaItem> playedPlaylist = [];
  bool shuffleEnabled = false;

  @override
  AudioState build() => AudioState();

  @override
  Future<void> playPlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
    String? playlistId,
  }) async {
    playedPlaylist = List.from(items);
  }

  @override
  void setShuffle(bool enabled) {
    shuffleEnabled = enabled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'blocked_tracks_list': [
        jsonEncode({
          'id': 'blocked_id_1',
          'title': 'Blocked Song 1',
          'artist': 'Blocked Artist',
          'blockedAt': DateTime.now().toIso8601String(),
        }),
        jsonEncode({
          'id': 'C:/Music/blocked_path.mp3',
          'title': 'Blocked Local Song',
          'artist': 'Local Artist',
          'blockedAt': DateTime.now().toIso8601String(),
        }),
      ],
    });
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioProvider.overrideWith(MockAudioNotifier.new),
        cachedStreamMusicProvider.overrideWith((ref) => [
          MediaItem(
            id: 'cached_unblocked',
            path: 'stream/audio/cached_unblocked.m4a',
            title: 'Cached Song',
            type: 'audio',
          ),
          MediaItem(
            id: 'blocked_id_1',
            path: 'stream/audio/blocked_id_1.m4a',
            title: 'Blocked Song 1',
            type: 'audio',
          ),
        ]),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('BlockedTracksNotifier Core Tests', () {
    test('Correctly loads blocked items and provides O(1) isBlocked checks', () {
      final notifier = container.read(blockedTracksProvider.notifier);

      expect(notifier.isBlocked('blocked_id_1'), isTrue);
      expect(notifier.isBlocked(null, path: 'C:/Music/blocked_path.mp3'), isTrue);
      expect(notifier.isBlocked('unblocked_id'), isFalse);
      expect(notifier.isBlocked(null, path: 'C:/Music/clean.mp3'), isFalse);
    });

    test('blockTrack and unblockTrack update state and lookup set', () async {
      final notifier = container.read(blockedTracksProvider.notifier);

      final newSong = MediaItem(
        id: 'new_blocked_song',
        path: 'new_blocked_song',
        title: 'Bad Song',
        type: 'audio',
      );

      await notifier.blockTrack(newSong);
      expect(notifier.isBlocked('new_blocked_song'), isTrue);

      await notifier.unblockTrack('new_blocked_song');
      expect(notifier.isBlocked('new_blocked_song'), isFalse);
    });
  });

  group('Feed & Carousel Blocked Filtering Logic', () {
    test('Filters out blocked tracks from media pools', () {
      final notifier = container.read(blockedTracksProvider.notifier);

      final feedPool = [
        MediaItem(id: 'song_1', path: 'path1', title: 'Clean Song 1', type: 'audio'),
        MediaItem(id: 'blocked_id_1', path: 'path2', title: 'Blocked Song 1', type: 'audio'),
        MediaItem(id: 'song_2', path: 'C:/Music/blocked_path.mp3', title: 'Local Blocked', type: 'audio'),
        MediaItem(id: 'song_3', path: 'path3', title: 'Clean Song 2', type: 'audio'),
      ];

      final filtered = feedPool
          .where((m) => !notifier.isBlocked(m.id, path: m.path))
          .toList();

      expect(filtered.length, equals(2));
      expect(filtered.map((e) => e.id), containsAll(['song_1', 'song_3']));
      expect(filtered.any((e) => e.id == 'blocked_id_1'), isFalse);
    });
  });

  group('QueueOrchestrator Blocked Containment Tests', () {
    test('playWithLocalRadioFallback aborts if chosen track is blocked', () {
      final orchestrator = container.read(queueOrchestratorProvider);
      final mockNotifier = container.read(audioProvider.notifier) as MockAudioNotifier;
      final blockedTrack = MediaItem(
        id: 'blocked_id_1',
        path: 'stream/audio/blocked_id_1.m4a',
        title: 'Blocked Song 1',
        type: 'audio',
      );

      orchestrator.playWithLocalRadioFallback(blockedTrack, []);
      expect(mockNotifier.playedPlaylist, isEmpty);
    });

    test('playWithLocalRadioFallback filters blocked tracks from fallback pool', () {
      final orchestrator = container.read(queueOrchestratorProvider);
      final mockNotifier = container.read(audioProvider.notifier) as MockAudioNotifier;
      final cleanSelectedTrack = MediaItem(
        id: 'clean_selected',
        path: 'stream/audio/clean.m4a',
        title: 'Clean Selected Song',
        type: 'audio',
      );

      final localPool = <MediaItem>[
        MediaItem(id: 'local_1', path: 'local1.mp3', title: 'Local 1', type: 'audio'),
        MediaItem(id: 'local_2', path: 'C:/Music/blocked_path.mp3', title: 'Blocked Local', type: 'audio'),
      ];

      orchestrator.playWithLocalRadioFallback(cleanSelectedTrack, localPool);

      expect(mockNotifier.playedPlaylist, isNotEmpty);
      expect(mockNotifier.playedPlaylist.first.id, equals('clean_selected'));
      expect(mockNotifier.playedPlaylist.any((t) => t.id == 'blocked_id_1'), isFalse);
      expect(mockNotifier.playedPlaylist.any((t) => t.path == 'C:/Music/blocked_path.mp3'), isFalse);
      expect(mockNotifier.playedPlaylist.any((t) => t.id == 'cached_unblocked'), isTrue);
      expect(mockNotifier.shuffleEnabled, isTrue);
    });

    test('playSequentialContext omits blocked tracks from context queue', () {
      final orchestrator = container.read(queueOrchestratorProvider);
      final mockNotifier = container.read(audioProvider.notifier) as MockAudioNotifier;
      final cleanTrack = MediaItem(
        id: 'clean_1',
        path: 'clean_1',
        title: 'Clean Track',
        type: 'audio',
      );

      final contextQueue = <MediaItem>[
        cleanTrack,
        MediaItem(id: 'blocked_id_1', path: 'b1', title: 'Blocked 1', type: 'audio'),
        MediaItem(id: 'clean_2', path: 'clean_2', title: 'Clean Track 2', type: 'audio'),
      ];

      orchestrator.playSequentialContext(cleanTrack, contextQueue);

      expect(mockNotifier.playedPlaylist.length, equals(2));
      expect(mockNotifier.playedPlaylist.any((t) => t.id == 'blocked_id_1'), isFalse);
    });
  });
}
