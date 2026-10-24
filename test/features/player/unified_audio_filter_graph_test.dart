import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/services/stream_resolution_service.dart';
import 'package:resonance/core/application/providers/window_lifecycle_provider.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';

void main() {
  group('Unified Audio Filter Graph & Core Audit Tests', () {
    test('MpvConfigurator.buildAudioFilter returns empty string when EQ is null or empty', () {
      final defaultFilter = MpvConfigurator.buildAudioFilter();
      expect(defaultFilter, equals(''));

      final emptyEqFilter = MpvConfigurator.buildAudioFilter('');
      expect(emptyEqFilter, equals(''));
    });

    test('MpvConfigurator.buildAudioFilter returns native equalizer chain when populated', () {
      const eqChain = 'equalizer=f=62.5:width_type=o:w=1:g=4.0,equalizer=f=1000.0:width_type=o:w=1:g=-2.0';
      final compositeFilter = MpvConfigurator.buildAudioFilter(eqChain);

      expect(compositeFilter, equals(eqChain));
    });

    test('isWindowRenderActiveProvider defaults to true and throttles on minimize/tray', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isWindowRenderActiveProvider), isTrue);

      container.read(isWindowRenderActiveProvider.notifier).state = false;
      expect(container.read(isWindowRenderActiveProvider), isFalse);

      container.read(isWindowRenderActiveProvider.notifier).state = true;
      expect(container.read(isWindowRenderActiveProvider), isTrue);
    });

    test('ThumbnailUtils.getFallbackResolution returns clean 16:9 mqdefault instead of 4:3 hqdefault', () {
      const maxresUrl = 'https://i.ytimg.com/vi/abc123xyz/maxresdefault.jpg';
      final fallback = ThumbnailUtils.getFallbackResolution(maxresUrl);

      expect(fallback, equals('https://i.ytimg.com/vi/abc123xyz/mqdefault.jpg'));
      expect(fallback, isNot(contains('hqdefault.jpg')));
    });

    test('ThumbnailUtils.toCardResolution transforms googleusercontent sizing to card specs', () {
      const lh3Url = 'https://lh3.googleusercontent.com/abc=w60-h60-l90-rj';
      final cardUrl = ThumbnailUtils.toCardResolution(lh3Url);
      expect(cardUrl, contains('=w400-h400-l90-rj'));
    });
  });
}
