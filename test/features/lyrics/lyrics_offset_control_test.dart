import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_offset_control.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class _FakeAudioNotifier extends AudioNotifier {
  @override
  AudioState build() => AudioState(
        currentTrack: MediaItem(
          id: 'test-track',
          title: 'Test Song',
          path: '/path/to/song.mp3',
          type: 'audio',
          lyricsOffset: Duration.zero,
        ),
      );

  @override
  void adjustLyricsOffset(Duration delta) {
    final current = state.currentTrack;
    if (current != null) {
      final updated = current.copyWith(
        lyricsOffset: current.lyricsOffset + delta,
      );
      state = state.copyWith(currentTrack: updated);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LyricsOffsetControl single click adjustments and reset', (tester) async {
    final audioNotifier = _FakeAudioNotifier();
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith(() => audioNotifier),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: LyricsOffsetControl()),
          ),
        ),
      ),
    );

    expect(find.text('0.0s'), findsOneWidget);

    // 1. Single click on '+' advances lyrics by 0.5s
    await tester.tap(find.byIcon(UIcons.regular.plus));
    await tester.pumpAndSettle();

    expect(find.text('0.5s'), findsOneWidget);

    // 2. Single click on '-' delays lyrics back to 0.0s
    await tester.tap(find.byIcon(UIcons.regular.minus));
    await tester.pumpAndSettle();

    expect(find.text('0.0s'), findsOneWidget);

    // 3. Click '+' twice -> 1.0s, then tap center badge to reset to 0.0s
    await tester.tap(find.byIcon(UIcons.regular.plus));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(UIcons.regular.plus));
    await tester.pumpAndSettle();

    expect(find.text('1.0s'), findsOneWidget);

    // Tap center badge to reset
    await tester.tap(find.text('1.0s'));
    await tester.pumpAndSettle();

    expect(find.text('0.0s'), findsOneWidget);
  });

  testWidgets('LyricsOffsetControl hold-to-accelerate repeats while pressed', (tester) async {
    final audioNotifier = _FakeAudioNotifier();
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith(() => audioNotifier),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: LyricsOffsetControl()),
          ),
        ),
      ),
    );

    // Hold down the plus button for 600ms (triggers 350ms delay + repeating ticks)
    final plusFinder = find.byIcon(UIcons.regular.plus);
    final gesture = await tester.startGesture(tester.getCenter(plusFinder));
    await tester.pump(const Duration(milliseconds: 100)); // Initial press (+0.5s)
    expect(find.text('0.5s'), findsOneWidget);

    // Advance 500ms -> triggers hold repeat timer
    await tester.pump(const Duration(milliseconds: 500));
    final currentOffset = container.read(audioProvider).currentTrack?.lyricsOffset.inMilliseconds ?? 0;
    expect(currentOffset, greaterThan(500));

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('LyricsOffsetControl absorbs gestures and prevents bubbling to parent card', (tester) async {
    final audioNotifier = _FakeAudioNotifier();
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith(() => audioNotifier),
      ],
    );
    addTearDown(container.dispose);

    int parentTapCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () => parentTapCount++,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.blue,
                  child: const LyricsOffsetControl(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap plus button
    await tester.tap(find.byIcon(UIcons.regular.plus));
    await tester.pumpAndSettle();
    expect(parentTapCount, 0);

    // Tap minus button
    await tester.tap(find.byIcon(UIcons.regular.minus));
    await tester.pumpAndSettle();
    expect(parentTapCount, 0);

    // Tap center badge when at 0.0s
    await tester.tap(find.text('0.0s'));
    await tester.pumpAndSettle();
    expect(parentTapCount, 0);
  });
}
