import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the desktop application window is currently active and visible for rendering.
/// When minimized or hidden to tray, this turns false so high-frequency rendering and timers can suspend.
class WindowRenderActiveNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  @override
  set state(bool value) => super.state = value;
}

final isWindowRenderActiveProvider =
    NotifierProvider<WindowRenderActiveNotifier, bool>(
  WindowRenderActiveNotifier.new,
);
