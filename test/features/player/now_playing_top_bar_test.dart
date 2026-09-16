import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/presentation/screens/now_playing_screen.dart';

void main() {
  group('Now Playing Top Bar Tests', () {
    testWidgets('Media Actions button uses horizontal dots and sits on edge right side', (tester) async {
      final track = MediaItem(
        id: 'test_1',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        path: 'https://example.com/audio.mp4',
        type: 'audio',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 80,
                child: NowPlayingTopBar(
                  track: track,
                  onClose: () {},
                  onQueue: () {},
                  onMediaActions: () {},
                  onAudioSettings: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify horizontal dots
      final menuDotsFinder = find.byWidgetPredicate(
        (widget) => widget is ReusableHoverIconButton && widget.icon == UIcons.regular.menu_dots,
      );
      expect(menuDotsFinder, findsOneWidget);

      // Verify no vertical dots
      final menuDotsVertFinder = find.byWidgetPredicate(
        (widget) => widget is ReusableHoverIconButton && widget.icon == UIcons.regular.menu_dots_vertical,
      );
      expect(menuDotsVertFinder, findsNothing);

      // Verify Audio Settings button exists
      final settingsFinder = find.byWidgetPredicate(
        (widget) => widget is ReusableHoverIconButton && widget.icon == UIcons.regular.settings_sliders,
      );
      expect(settingsFinder, findsOneWidget);

      // Verify Media Actions is to the right of Audio Settings
      final settingsPos = tester.getCenter(settingsFinder);
      final mediaActionsPos = tester.getCenter(menuDotsFinder);
      expect(mediaActionsPos.dx, greaterThan(settingsPos.dx));
    });
  });
}
