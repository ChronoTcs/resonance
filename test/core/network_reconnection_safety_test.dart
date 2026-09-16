import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/settings/application/update_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/audio_handler.dart';
import 'package:resonance/features/playlist/application/services/playlist_stream_cache_handler.dart';
import 'package:resonance/features/download/application/download_service.dart';
import 'package:resonance/features/download/data/models/download_item.dart';

class _MockUpdateNotifier extends UpdateNotifier {
  @override
  UpdateState build() => UpdateState();

  @override
  Future<void> checkForUpdate() async {}
}

class _MockAudioNotifier extends AudioNotifier {
  @override
  AudioState build() => AudioState();
}

class _MockAudioHandler extends BaseAudioHandler implements ResonanceAudioHandler {
  @override
  Player get player => throw UnimplementedError();

  @override
  VoidCallback? onSkipToNext;

  @override
  VoidCallback? onSkipToPrevious;
}

class _MockPlaylistStreamCacheHandler extends Fake implements PlaylistStreamCacheHandler {
  bool processPendingQueueCalled = false;

  @override
  Future<void> processPendingQueue() async {
    processPendingQueueCalled = true;
  }
}

class _FakeDownloadService extends Fake implements DownloadService {
  @override
  Stream<DownloadUpdate> get updateStream => const Stream.empty();

  @override
  Future<void> scheduleNext(List<DownloadItem> queue) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;
  late _MockPlaylistStreamCacheHandler mockPlaylistStreamCacheHandler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    PackageInfo.setMockInitialValues(
      appName: 'Resonance',
      packageName: 'com.streamly.resonance',
      version: '0.1.7',
      buildNumber: '1',
      buildSignature: '',
    );

    mockPlaylistStreamCacheHandler = _MockPlaylistStreamCacheHandler();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateProvider.overrideWith(_MockUpdateNotifier.new),
        audioProvider.overrideWith(_MockAudioNotifier.new),
        audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
        playlistStreamCacheHandlerProvider.overrideWithValue(mockPlaylistStreamCacheHandler),
        downloadServiceProvider.overrideWithValue(_FakeDownloadService()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Network Reconnection Circular Dependency & Invalidation Safety (Phase 18)', () {
    test('Offline to online transition updates state cleanly without CircularDependencyError', () async {
      final notifier = container.read(networkConnectivityProvider.notifier);

      // Force offline initially
      notifier.simulateOfflineForTesting();
      expect(container.read(networkConnectivityProvider).isOnline, isFalse);

      // Define a consumer provider that selects isOnline (identical pattern to exploreProvider / homeFeedProvider)
      int computationCount = 0;
      final testFeedProvider = FutureProvider<String>((ref) async {
        final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));
        computationCount++;
        if (!isOnline) return 'cached_offline_feed';
        return 'fresh_online_feed';
      });

      // Initial read when offline
      final offlineResult = await container.read(testFeedProvider.future);
      expect(offlineResult, equals('cached_offline_feed'));
      expect(computationCount, equals(1));

      // Simulate network reconnection (which schedules _onReconnected via microtask)
      notifier.simulateReconnectionForTesting();

      // State is immediately online
      expect(container.read(networkConnectivityProvider).isOnline, isTrue);

      // Allow microtask queue to drain and background tasks to execute
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Feed provider should automatically refresh to fresh_online_feed via select watch
      final onlineResult = await container.read(testFeedProvider.future);
      expect(onlineResult, equals('fresh_online_feed'));
      expect(computationCount, equals(2));

      // Verify deferred background tasks executed safely
      expect(mockPlaylistStreamCacheHandler.processPendingQueueCalled, isTrue);
    });

    test('Multiple dependent providers recompute without race conditions or cycle errors', () async {
      final notifier = container.read(networkConnectivityProvider.notifier);
      notifier.simulateOfflineForTesting();

      // Provider A: Watches network online state
      final providerA = Provider<bool>((ref) {
        return ref.watch(networkConnectivityProvider.select((s) => s.isOnline));
      });

      // Provider B: Watches Provider A and computes derived status
      final providerB = Provider<String>((ref) {
        final online = ref.watch(providerA);
        return online ? 'READY_ONLINE' : 'FALLBACK_OFFLINE';
      });

      expect(container.read(providerA), isFalse);
      expect(container.read(providerB), equals('FALLBACK_OFFLINE'));

      // Reconnect
      notifier.simulateReconnectionForTesting();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(providerA), isTrue);
      expect(container.read(providerB), equals('READY_ONLINE'));
    });

    test('Rapid consecutive offline-online-offline cycles do not throw or leak state', () async {
      final notifier = container.read(networkConnectivityProvider.notifier);

      for (int i = 0; i < 5; i++) {
        notifier.simulateOfflineForTesting();
        expect(container.read(networkConnectivityProvider).isOnline, isFalse);

        notifier.simulateReconnectionForTesting();
        expect(container.read(networkConnectivityProvider).isOnline, isTrue);
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(networkConnectivityProvider).isOnline, isTrue);
    });
  });
}
