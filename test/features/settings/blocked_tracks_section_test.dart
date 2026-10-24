import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/theme/app_theme.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/library/data/models/blocked_track.dart';
import 'package:resonance/features/settings/presentation/widgets/blocked_tracks_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({required List<BlockedTrack> initialTracks}) {
    return ProviderScope(
      overrides: [
        blockedTracksProvider.overrideWith(
          () => _FakeBlockedTracksNotifier(initialTracks),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.getDarkTheme(null),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: BlockedTracksSection(),
            ),
          ),
        ),
      ),
    );
  }

  group('BlockedTracksSection UI De-Slop Tests', () {
    testWidgets('Empty state renders clean single view without redundant header or search bar',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(initialTracks: []));
      await tester.pumpAndSettle();

      // Top summary card & search bar should NOT exist when list is empty
      expect(find.textContaining('0 Blocked'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // Clean empty state should be displayed
      expect(find.text('No Blocked Tracks'), findsOneWidget);
      expect(
        find.textContaining('Tracks you block will appear here'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Use the 3-dots menu or right-click on any track to block it'),
        findsOneWidget,
      );

      // Security shield icon should NOT be used; music_slash icon must be used
      expect(find.byIcon(UIcons.regular.shield_check), findsNothing);
      expect(find.byIcon(UIcons.regular.music_slash), findsOneWidget);
    });

    testWidgets('Populated state renders summary header, search bar, and track rows',
        (tester) async {
      final sampleTracks = [
        BlockedTrack(
          id: 'track_1',
          title: 'Unwanted Song',
          artist: 'Bad Artist',
          blockedAt: DateTime.now(),
        ),
        BlockedTrack(
          id: 'track_2',
          title: 'Annoying Track',
          artist: 'Another Artist',
          blockedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(initialTracks: sampleTracks));
      await tester.pumpAndSettle();

      // Summary header should be visible with count and unblock all action
      expect(find.text('2 Blocked Tracks'), findsOneWidget);
      expect(find.text('Unblock All'), findsOneWidget);

      // Search bar should be visible
      expect(find.byType(TextField), findsOneWidget);

      // Empty state should NOT be visible
      expect(find.text('No Blocked Tracks'), findsNothing);

      // Track items should be rendered
      expect(find.text('Unwanted Song'), findsOneWidget);
      expect(find.text('Annoying Track'), findsOneWidget);
    });
  });
}

class _FakeBlockedTracksNotifier extends BlockedTracksNotifier {
  final List<BlockedTrack> _initial;

  _FakeBlockedTracksNotifier(this._initial);

  @override
  List<BlockedTrack> build() => _initial;

  @override
  Future<void> clearAll() async {
    state = [];
  }
}
