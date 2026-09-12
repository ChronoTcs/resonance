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
    setVisible(!state);
  }

  void setVisible(bool visible) {
    state = visible;
    if (!visible) {
      ref.read(lyricsOverlayProvider.notifier).setVisible(false);
      ref.read(queueOverlayProvider.notifier).setVisible(false);
    }
  }
}

final nowPlayingOverlayProvider = NotifierProvider<NowPlayingOverlayNotifier, bool>(() {
  return NowPlayingOverlayNotifier();
});

class QueueOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setVisible(bool visible) {
    state = visible;
  }
}

final queueOverlayProvider = NotifierProvider<QueueOverlayNotifier, bool>(() {
  return QueueOverlayNotifier();
});

class QueueWindowNotifier extends Notifier<int> {
  @override
  int build() => 20;

  void setWindowSize(int size) {
    state = size;
  }
}

final queueWindowSizeProvider = NotifierProvider<QueueWindowNotifier, int>(() {
  return QueueWindowNotifier();
});
