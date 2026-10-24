import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:audio_service/audio_service.dart' hide MediaItem;
import 'package:media_kit/media_kit.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/media/media_artwork_widget.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_queue_section.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_recommendation_section.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_top_bar.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/audio_handler.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

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

  @override
  VoidCallback? onPlay;

  @override
  VoidCallback? onPause;

  @override
  VoidCallback? onStop;

  @override
  void notifyQueueCompleted() {}
}

class _MockExpandedNotifier extends RightSidebarExpandedNotifier {
  @override
  bool build() => true;
}

void main() {
  testWidgets('RightSidebar renders unified sections clipped at shrunk rail width by default', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
          audioProvider.overrideWith(_MockAudioNotifier.new),
          quickPicksProvider.overrideWith((ref) => Future.value(<MediaItem>[])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RightSidebar(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RightSidebarTopBar), findsOneWidget);
    expect(find.byType(RightSidebarQueueSection), findsOneWidget);
    expect(find.byType(RightSidebarRecommendationSection), findsOneWidget);

    expect(tester.getRect(find.byType(RightSidebar)).width, equals(70.0));
  });

  testWidgets('RightSidebar expands to 310 width when expanded provider is true', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
          audioProvider.overrideWith(_MockAudioNotifier.new),
          quickPicksProvider.overrideWith((ref) => Future.value(<MediaItem>[])),
          rightSidebarExpandedProvider.overrideWith(_MockExpandedNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RightSidebar(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RightSidebarTopBar), findsOneWidget);
    expect(find.byType(RightSidebarQueueSection), findsOneWidget);
    expect(find.byType(RightSidebarRecommendationSection), findsOneWidget);

    expect(tester.getRect(find.byType(RightSidebar)).width, equals(310.0));
  });

  testWidgets('RightSidebar renders cards and zero overflow', (tester) async {
    final longTrack = MediaItem(
      id: 'long_track_1',
      title: 'A Very Long Song Title That Exceeds Normal Constraints And Should Marquee Scroll',
      artist: 'An Extremely Long Artist Name Feat. Multiple Guest Collaborators And Producers',
      album: 'Album',
      path: 'https://example.com/audio.mp3',
      type: 'audio',
      albumArt: Uint8List(0),
      duration: const Duration(minutes: 3, seconds: 45),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
          audioProvider.overrideWith(() => _MockPopulatedAudioNotifier(longTrack)),
          quickPicksProvider.overrideWith((ref) => Future.value(<MediaItem>[longTrack])),
          rightSidebarExpandedProvider.overrideWith(_MockExpandedNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 310,
              height: 700,
              child: RightSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(longTrack.title), findsAtLeastNWidgets(1));
    expect(find.text(longTrack.artist!), findsAtLeastNWidgets(1));
    // Verify no overflow exceptions occurred
    expect(tester.takeException(), isNull);
  });

  testWidgets('RightSidebarQueueSection renders ReorderableListView with ReusableHoverIconButton', (tester) async {
    final track1 = MediaItem(
      id: 'track_1',
      title: 'Track 1',
      artist: 'Artist 1',
      album: 'Album',
      path: 'https://example.com/1.mp3',
      type: 'audio',
      albumArt: Uint8List(0),
    );
    final track2 = MediaItem(
      id: 'track_2',
      title: 'Track 2',
      artist: 'Artist 2',
      album: 'Album',
      path: 'https://example.com/2.mp3',
      type: 'audio',
      albumArt: Uint8List(0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
          audioProvider.overrideWith(() => _MockMultipleTracksAudioNotifier([track1, track2])),
          quickPicksProvider.overrideWith((ref) => Future.value(<MediaItem>[track1])),
          rightSidebarExpandedProvider.overrideWith(_MockExpandedNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 310,
              height: 700,
              child: RightSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify ReorderableListView is present
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(ReorderableDelayedDragStartListener), findsNWidgets(2));
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

    // Verify 'Playing Queue' title is rendered without truncation
    expect(find.text('Playing Queue'), findsOneWidget);
    expect(find.textContaining('Playing Que...'), findsNothing);

    // Verify ReusableHoverIconButton is used for sidebar buttons
    expect(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Shuffle Off'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Clear Upcoming Queue'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Refresh Recommendations'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Collapse Sidebar'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('RightSidebar locks artwork horizontal placement (dx=16) and shows waveform badge when minimized', (tester) async {
    final currentTrack = MediaItem(
      id: 'current_1',
      title: 'Current Song',
      artist: 'Artist',
      album: 'Album',
      path: 'https://example.com/curr.mp3',
      type: 'audio',
      albumArt: Uint8List(0),
    );
    final recTrack = MediaItem(
      id: 'rec_1',
      title: 'Recommended Song',
      artist: 'Rec Artist',
      album: 'Album',
      path: 'https://example.com/rec.mp3',
      type: 'audio',
      albumArt: Uint8List(0),
    );

    // 1. Minimized mode (width = 70)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
          audioProvider.overrideWith(() => _MockPopulatedAudioNotifier(currentTrack)),
          quickPicksProvider.overrideWith((ref) => Future.value(<MediaItem>[recTrack])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 70,
              height: 700,
              child: RightSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify waveform badge is present in minimized mode for current track
    expect(find.byIcon(UIcons.regular.waveform_path), findsOneWidget);

    // Verify first artwork (Queue card) is anchored at dx = 16.0
    final queueArtworkOffset = tester.getTopLeft(find.byType(MediaArtworkWidget).first);
    expect(queueArtworkOffset.dx, equals(16.0));

    // Verify second artwork (Recommendation card) is also anchored at dx = 16.0
    final recArtworkOffset = tester.getTopLeft(find.byType(MediaArtworkWidget).at(1));
    expect(recArtworkOffset.dx, equals(16.0));

    // 2. Expand sidebar by tapping the top bar expand button
    await tester.tap(
      find.byWidgetPredicate((w) => w is ReusableHoverIconButton && w.tooltip == 'Expand Sidebar'),
    );
    await tester.pumpAndSettle();

    // Verify artwork in expanded mode is STILL anchored at dx = 16.0 (Zero jumping!)
    final expandedQueueArtworkOffset = tester.getTopLeft(find.byType(MediaArtworkWidget).first);
    expect(expandedQueueArtworkOffset.dx, equals(16.0));
    final expandedRecArtworkOffset = tester.getTopLeft(find.byType(MediaArtworkWidget).at(1));
    expect(expandedRecArtworkOffset.dx, equals(16.0));

    expect(tester.takeException(), isNull);
  });

  testWidgets('RightSidebar queue and recommendation sections both utilize Silky scroll and RawScrollbar', (tester) async {
    final track1 = MediaItem(
      id: 'track_1',
      title: 'Track 1',
      artist: 'Artist 1',
      album: 'Album',
      path: 'https://example.com/1.mp3',
      type: 'audio',
      albumArt: Uint8List(0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_MockAudioHandler()),
          audioProvider.overrideWith(() => _MockPopulatedAudioNotifier(track1)),
          quickPicksProvider.overrideWith((ref) => Future.value(<MediaItem>[track1])),
          rightSidebarExpandedProvider.overrideWith(_MockExpandedNotifier.new),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: const Scaffold(
            body: SizedBox(
              width: 310,
              height: 700,
              child: RightSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify exactly one Scrollbar per section (no duplicate scrollbars)
    expect(find.byType(Scrollbar), findsNWidgets(2));
    expect(find.byType(SilkyScroll), findsAtLeastNWidgets(1));
    expect(find.byType(SilkyListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MockMultipleTracksAudioNotifier extends AudioNotifier {
  final List<MediaItem> tracks;
  _MockMultipleTracksAudioNotifier(this.tracks);

  @override
  AudioState build() => AudioState(
        queue: tracks,
        currentIndex: 0,
        currentTrack: tracks.isNotEmpty ? tracks.first : null,
      );
}

class _MockPopulatedAudioNotifier extends AudioNotifier {
  final MediaItem track;
  _MockPopulatedAudioNotifier(this.track);

  @override
  AudioState build() => AudioState(
        queue: [track],
        currentIndex: 0,
        currentTrack: track,
      );
}
