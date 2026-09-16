import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/data/services/discord_rpc_service.dart';

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
  });
}
