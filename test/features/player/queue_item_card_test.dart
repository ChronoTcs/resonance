import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/presentation/widgets/queue/queue_item_card.dart';

void main() {
  group('QueueItemCard UI Tests', () {
    testWidgets('Renders clean ordinal number without N+ prefix', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final track = MediaItem(
        id: 'test_1',
        title: 'Mind Games',
        artist: 'Sickick',
        album: 'Single',
        path: 'https://example.com/audio.mp4',
        type: 'audio',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QueueItemCard(
                track: track,
                positionTag: '1',
                index: 0,
                onTap: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      // Verify clean number '1' exists
      expect(find.text('1'), findsOneWidget);

      // Verify 'N+' or 'N+1' does NOT exist
      expect(find.textContaining('N+'), findsNothing);

      // Verify track metadata
      expect(find.text('Mind Games'), findsOneWidget);
      expect(find.text('Sickick'), findsOneWidget);
    });
  });
}
