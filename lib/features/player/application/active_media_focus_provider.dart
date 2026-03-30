import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MediaFocus { audio, video }

class MediaFocusNotifier extends Notifier<MediaFocus> {
  @override
  MediaFocus build() => MediaFocus.audio;

  void setFocus(MediaFocus focus) {
    if (state != focus) {
      state = focus;
    }
  }

  void setAudioFocus() => setFocus(MediaFocus.audio);
  void setVideoFocus() => setFocus(MediaFocus.video);
}

final mediaFocusProvider = NotifierProvider<MediaFocusNotifier, MediaFocus>(() {
  return MediaFocusNotifier();
});
