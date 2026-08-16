import 'package:flutter_riverpod/flutter_riverpod.dart';

class LyricsOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setVisible(bool visible) {
    state = visible;
  }
}

final lyricsOverlayProvider = NotifierProvider<LyricsOverlayNotifier, bool>(() {
  return LyricsOverlayNotifier();
});

class NowPlayingOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setVisible(bool visible) {
    state = visible;
  }
}

final nowPlayingOverlayProvider = NotifierProvider<NowPlayingOverlayNotifier, bool>(() {
  return NowPlayingOverlayNotifier();
});
