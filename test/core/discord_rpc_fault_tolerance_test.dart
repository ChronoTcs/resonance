import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/data/services/discord_rpc_service.dart';
import 'package:resonance/core/domain/models/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('DiscordRpcService Fault-Tolerance & Safe State Tests', () {
    test('isInitialized defaults to false when Discord client is not running', () {
      final rpcService = container.read(discordRpcServiceProvider);
      expect(rpcService.isInitialized, isFalse);
    });

    test('clearPresence executes safely without throwing when uninitialized', () {
      final rpcService = container.read(discordRpcServiceProvider);
      expect(() => rpcService.clearPresence(), returnsNormally);
      expect(rpcService.isInitialized, isFalse);
    });

    test('dispose executes safely without throwing when uninitialized', () {
      final rpcService = container.read(discordRpcServiceProvider);
      expect(() => rpcService.dispose(), returnsNormally);
      expect(rpcService.isInitialized, isFalse);
    });

    test('updatePresence returns null safely when track is null or uninitialized', () async {
      final rpcService = container.read(discordRpcServiceProvider);

      final resultNullTrack = await rpcService.updatePresence(
        null,
        Duration.zero,
        Duration.zero,
        false,
      );
      expect(resultNullTrack, isNull);

      // Verify dispose guarantees uninitialized state and safe teardown
      rpcService.dispose();
      expect(rpcService.isInitialized, isFalse);
      expect(() => rpcService.clearPresence(), returnsNormally);
    });

    test('updatePresence payload verifies playing state includes timestamps and omits buttons for progress bar', () async {
      final rpcService = container.read(discordRpcServiceProvider);
      const channel = MethodChannel('com.chronostudio.resonance/discord_rpc');
      final calls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initialize') return true;
        if (call.method == 'updatePresence') return true;
        return null;
      });

      await rpcService.initialize();
      expect(rpcService.isInitialized, isTrue);

      final track = MediaItem(
        id: 'track_123',
        path: 'path/to/song.mp3',
        title: 'Song Title',
        artist: 'Artist Name',
        type: 'audio',
        duration: const Duration(seconds: 180),
      );

      // Playback active
      await rpcService.updatePresence(
        track,
        const Duration(seconds: 30),
        const Duration(seconds: 180),
        true,
      );

      final playCall = calls.firstWhere((c) => c.method == 'updatePresence');
      final playArgs = Map<String, dynamic>.from(playCall.arguments as Map);

      expect(playArgs['details'], equals('Song Title'));
      expect(playArgs['state'], equals('Artist Name'));
      expect(playArgs['startTimestamp'], isNotNull);
      expect(playArgs['endTimestamp'], isNotNull);
      expect(playArgs['smallImage'], isNull);
      expect(playArgs['smallText'], isNull);
      // On Windows buttons are always present; on Android omitted during playback for scrubber
      expect(playArgs['button2Label'], equals(Platform.isWindows ? 'Play on Resonance' : null));

      // Now pause
      calls.clear();
      await rpcService.updatePresence(
        track,
        const Duration(seconds: 30),
        const Duration(seconds: 180),
        false,
      );

      final pauseCall = calls.firstWhere((c) => c.method == 'updatePresence');
      final pauseArgs = Map<String, dynamic>.from(pauseCall.arguments as Map);

      // When paused: timestamps MUST be null, smallImage/smallText null, and action buttons present
      expect(pauseArgs['startTimestamp'], isNull);
      expect(pauseArgs['endTimestamp'], isNull);
      expect(pauseArgs['smallImage'], isNull);
      expect(pauseArgs['smallText'], isNull);
      expect(pauseArgs['button2Label'], equals('Play on Resonance'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
