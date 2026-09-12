import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/storage_service.dart';

final playlistAutoContinueProvider =
    NotifierProvider<PlaylistAutoContinueNotifier, Set<String>>(() {
  return PlaylistAutoContinueNotifier();
});

class PlaylistAutoContinueNotifier extends Notifier<Set<String>> {
  static const String _key = 'playlist_auto_continue_ids';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final list = prefs.getStringList(_key) ?? const [];
    return list.toSet();
  }

  bool isEnabled(String playlistId) => state.contains(playlistId);

  void toggle(String playlistId) {
    final next = Set<String>.from(state);
    if (next.contains(playlistId)) {
      next.remove(playlistId);
    } else {
      next.add(playlistId);
    }
    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
    state = next;
  }

  void setEnabled(String playlistId, bool value) {
    final next = Set<String>.from(state);
    if (value) {
      next.add(playlistId);
    } else {
      next.remove(playlistId);
    }
    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
    state = next;
  }
}
