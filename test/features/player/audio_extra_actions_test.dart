import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart' hide MediaItem;
import 'package:media_kit/media_kit.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/audio_handler.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_extra_actions.dart';

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

void main() {
  group('AudioExtraActions Desktop Layout Tests', () {
    testWidgets('Media actions button uses horizontal dots and sits right of Fullscreen button', (tester) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final track = MediaItem(
        id: 'test_track_1',
        title: 'I Was Never There',
        artist: 'The Weeknd',
        album: 'My Dear Melancholy,',
        path: 'https://example.com/stream.mp4',
        type: 'audio',
        duration: const Duration(minutes: 4, seconds: 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
            audioProvider.overrideWith(_MockAudioNotifier.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 80,
                child: AudioExtraActions(
                  track: track,
                  isDesktop: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify horizontal dots (menu_dots) exists
      final menuDotsFinder = find.byWidgetPredicate(
        (widget) => widget is ReusableHoverIconButton && widget.icon == UIcons.regular.menu_dots,
      );
      expect(menuDotsFinder, findsOneWidget);

      // Verify vertical dots (menu_dots_vertical) is NOT used on desktop
      final menuDotsVertFinder = find.byWidgetPredicate(
        (widget) => widget is ReusableHoverIconButton && widget.icon == UIcons.regular.menu_dots_vertical,
      );
      expect(menuDotsVertFinder, findsNothing);

      // Verify fullscreen button exists
      final fullscreenFinder = find.byWidgetPredicate(
        (widget) => widget is ReusableHoverIconButton && widget.icon == UIcons.regular.expand,
      );
      expect(fullscreenFinder, findsOneWidget);

      // Verify media actions button is positioned to the right of the fullscreen button
      final fullscreenPos = tester.getCenter(fullscreenFinder);
      final mediaActionsPos = tester.getCenter(menuDotsFinder);
      expect(mediaActionsPos.dx, greaterThan(fullscreenPos.dx));

      // Verify time text is positioned to the left of the fullscreen button
      final timeFinder = find.textContaining('00:00 / 00:00');
      expect(timeFinder, findsOneWidget);
      final timePos = tester.getCenter(timeFinder);
      expect(timePos.dx, lessThan(fullscreenPos.dx));
    });
  });
}
