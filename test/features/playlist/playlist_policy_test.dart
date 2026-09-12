import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/player/application/states/audio_state.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

void main() {
  group('AudioState Playlist Tracking', () {
    test('tracks activePlaylistId independently and clears cleanly', () {
      final state = AudioState(
        isPlaylistMode: true,
        activePlaylistId: 'pl_favorites',
        currentTrack: MediaItem(id: 'song1', title: 'Test', path: 'p1', type: 'audio'),
      );

      expect(state.isPlaylistMode, isTrue);
      expect(state.activePlaylistId, equals('pl_favorites'));

      // Switch to different playlist
      final switchedState = state.copyWith(activePlaylistId: 'pl_workout');
      expect(switchedState.activePlaylistId, equals('pl_workout'));

      // Clear on single track play outside playlist
      final clearedState = switchedState.copyWith(
        isPlaylistMode: false,
        clearActivePlaylistId: true,
      );
      expect(clearedState.isPlaylistMode, isFalse);
      expect(clearedState.activePlaylistId, isNull);
    });
  });

  group('Per-Playlist Auto-Continue & Auto-Cache Set Logic', () {
    test('scopes toggles per playlist ID without global leakage', () {
      final enabledAutoContinue = <String>{};

      void toggleAutoContinue(String id) {
        if (enabledAutoContinue.contains(id)) {
          enabledAutoContinue.remove(id);
        } else {
          enabledAutoContinue.add(id);
        }
      }

      // Toggle pl_1
      toggleAutoContinue('pl_1');
      expect(enabledAutoContinue.contains('pl_1'), isTrue);
      expect(enabledAutoContinue.contains('pl_2'), isFalse);

      // Toggle pl_2
      toggleAutoContinue('pl_2');
      expect(enabledAutoContinue.contains('pl_1'), isTrue);
      expect(enabledAutoContinue.contains('pl_2'), isTrue);

      // Toggle pl_1 off
      toggleAutoContinue('pl_1');
      expect(enabledAutoContinue.contains('pl_1'), isFalse);
      expect(enabledAutoContinue.contains('pl_2'), isTrue);
    });
  });
}
