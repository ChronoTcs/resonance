import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/providers/overlay_provider.dart';

class MainNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    ref.read(nowPlayingOverlayProvider.notifier).setVisible(false);
    ref.read(lyricsOverlayProvider.notifier).setVisible(false);
    state = index;
  }
}

/// Provider to manage the global navigation state (currently active tab in MainDashboard)
final mainNavigationProvider = NotifierProvider<MainNavigationNotifier, int>(() {
  return MainNavigationNotifier();
});
