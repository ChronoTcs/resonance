import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/lyrics/application/lyrics_provider.dart';
import 'package:resonance/features/lyrics/application/lyrics_translation_provider.dart';
import 'package:resonance/features/lyrics/data/models/lyric_line.dart';
import 'package:resonance/features/lyrics/presentation/widgets/lyrics_list_view.dart';
import 'package:resonance/features/lyrics/presentation/widgets/word_synced_lyric_row.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class _FakeLyricsNotifier extends LyricsNotifier {
  final List<LyricLine> _sample;
  _FakeLyricsNotifier(this._sample);

  @override
  LyricsState build() => LyricsState(lyrics: _sample);
}

class _FakeLyricsTranslationNotifier extends LyricsTranslationNotifier {
  @override
  LyricsTranslationState build() => LyricsTranslationState();
}

class _FakeAudioNotifier extends AudioNotifier {
  @override
  AudioState build() => AudioState(isPlaying: true);
}

class _TestActiveIndexNotifier extends Notifier<int> {
  @override
  int build() => -1;

  void setIndex(int idx) => state = idx;
}

final _testActiveIndexProvider =
    NotifierProvider<_TestActiveIndexNotifier, int>(() => _TestActiveIndexNotifier());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleLyrics = [
    LyricLine(
      timestamp: const Duration(seconds: 5),
      text: 'First line of lyrics',
    ),
    LyricLine(
      timestamp: const Duration(seconds: 10),
      text: 'Second line of lyrics',
    ),
    LyricLine(
      timestamp: const Duration(seconds: 15),
      text: 'Third line of lyrics',
    ),
  ];

  testWidgets(
      'LyricsListView in compact mode displays first line cleanly without blank dummy offset',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith(() => _FakeAudioNotifier()),
        lyricsProvider.overrideWith(() => _FakeLyricsNotifier(sampleLyrics)),
        lyricsTranslationProvider
            .overrideWith(() => _FakeLyricsTranslationNotifier()),
        activeLyricIndexProvider.overrideWith(
          (ref) => ref.watch(_testActiveIndexProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 250,
              child: LyricsListView(compact: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify first line is rendered and visible right from mount
    expect(find.text('First line of lyrics'), findsOneWidget);

    // Transition to first lyric active (intro finishes -> activeIndex = 0)
    container.read(_testActiveIndexProvider.notifier).setIndex(0);
    await tester.pumpAndSettle();

    // Verify first line is active
    final firstLineFinder = find.ancestor(
      of: find.text('First line of lyrics'),
      matching: find.byType(WordSyncedLyricRow),
    );
    expect(firstLineFinder, findsOneWidget);
    final firstLineWidget = tester.widget<WordSyncedLyricRow>(firstLineFinder);
    expect(firstLineWidget.isActive, isTrue);

    // Verify first line is within visible bounds of the 250px container
    final renderBox = tester.renderObject(firstLineFinder) as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero);
    expect(pos.dy, greaterThanOrEqualTo(0.0));
    expect(pos.dy, lessThan(250.0));
  });

  testWidgets(
      'mounting LyricsListView mid-track (e.g. opening full-screen or resizing) initializes without spurious scroll animation',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith(() => _FakeAudioNotifier()),
        lyricsProvider.overrideWith(() => _FakeLyricsNotifier(sampleLyrics)),
        lyricsTranslationProvider
            .overrideWith(() => _FakeLyricsTranslationNotifier()),
        activeLyricIndexProvider.overrideWith(
          (ref) => 1, // Mid-track at second line
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 250,
              child: LyricsListView(compact: true),
            ),
          ),
        ),
      ),
    );
    // Single pump (no pumpAndSettle animation needed)
    await tester.pump();

    // Verify second line is rendered immediately
    final secondLineFinder =
        find.widgetWithText(WordSyncedLyricRow, 'Second line of lyrics');
    expect(secondLineFinder, findsWidgets);

    final secondLineWidget =
        tester.widget<WordSyncedLyricRow>(secondLineFinder.first);
    expect(secondLineWidget.isActive, isTrue);
  });
}

