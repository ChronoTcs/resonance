import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/stream/platform/windows/windows_jump_list_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeAudioNotifier fakeAudio;
  final List<MethodCall> methodCalls = [];

  setUp(() async {
    methodCalls.clear();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('resonance/jump_list'),
      (MethodCall call) async {
        methodCalls.add(call);
        if (call.method == 'updateJumpList') return true;
        if (call.method == 'clearJumpList') return true;
        return null;
      },
    );

    fakeAudio = _FakeAudioNotifier();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recentlyPlayedProvider.overrideWith(() => _MockRecentlyPlayedNotifier()),
        libraryProvider.overrideWith(() => _MockLibraryNotifier()),
        audioProvider.overrideWith(() => fakeAudio),
      ],
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('resonance/jump_list'),
      null,
    );
    container.dispose();
  });

  group('WindowsJumpListService Command Parsing & Actions', () {
    test('parses --action=toggle-play and calls togglePlayPause', () async {
      final service = container.read(windowsJumpListServiceProvider);
      expect(fakeAudio.playToggled, isFalse);

      await service.handleCommandLine('--action=toggle-play');
      expect(fakeAudio.playToggled, isTrue);
    });

    test('parses --action=next-track and calls next', () async {
      final service = container.read(windowsJumpListServiceProvider);
      expect(fakeAudio.nextCalled, isFalse);

      await service.handleCommandLine('--action=next-track');
      expect(fakeAudio.nextCalled, isTrue);
    });

    test('parses --action=search and sets navigation index to 1', () async {
      final service = container.read(windowsJumpListServiceProvider);
      expect(container.read(mainNavigationProvider), 0);

      await service.handleCommandLine('--action=search');
      expect(container.read(mainNavigationProvider), 1);
    });

    test('ignores empty or whitespace command line string', () async {
      final service = container.read(windowsJumpListServiceProvider);
      await service.handleCommandLine('   ');
      expect(container.read(mainNavigationProvider), 0);
      expect(fakeAudio.lastPlayed, isNull);
    });

    test('parses --play-track from recent list and plays existing track', () async {
      final service = container.read(windowsJumpListServiceProvider);
      await service.handleCommandLine('--play-track="song1"');
      expect(fakeAudio.lastPlayed?.title, 'First Song');
    });

    test('parses --play-track unknown ID and plays as online track', () async {
      final service = container.read(windowsJumpListServiceProvider);
      await service.handleCommandLine('--play-track="unknown_yt_video_99"');
      expect(fakeAudio.lastPlayed?.id, 'unknown_yt_video_99');
      expect(fakeAudio.lastPlayed?.isStreaming, isTrue);
    });
  });
}

class _FakeAudioNotifier extends AudioNotifier {
  MediaItem? lastPlayed;
  bool playToggled = false;
  bool nextCalled = false;

  @override
  AudioState build() => AudioState();

  @override
  void togglePlayPause() {
    playToggled = true;
  }

  @override
  void next({bool fromCompletion = false}) {
    nextCalled = true;
  }

  @override
  Future<void> playTrack(MediaItem item, {int index = -1}) async {
    lastPlayed = item;
  }
}

class _MockRecentlyPlayedNotifier extends RecentlyPlayedNotifier {
  @override
  Future<List<MediaItem>> build() async {
    return [
      MediaItem(id: 'song1', path: 'song1', title: 'First Song', artist: 'Artist 1', type: 'audio'),
      MediaItem(id: 'song2', path: 'song2', title: 'Second Song', artist: 'Artist 2', type: 'audio'),
    ];
  }
}

class _MockLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() => LibraryState();
}
