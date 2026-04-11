import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier to manage the visibility of player controls with auto-hide logic.
/// Updated to latest manual Riverpod syntax as requested.
class PlayerUINotifier extends Notifier<bool> {
  Timer? _hideTimer;

  @override
  bool build() {
    // Ensure timer is cancelled when the provider is destroyed
    ref.onDispose(() => _hideTimer?.cancel());
    return true; // Default: Controls visible
  }

  /// Toggles visibility. If becoming visible and [isPlaying] is true, starts auto-hide timer.
  void toggle(bool isPlaying) {
    state = !state;
    if (state && isPlaying) {
      _startTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  /// Forces controls to be visible. If [isPlaying] is true, restarts the auto-hide timer.
  void show(bool isPlaying) {
    state = true;
    if (isPlaying) {
      _startTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  /// Hides controls immediately and cancels any active timer.
  void hide() {
    state = false;
    _hideTimer?.cancel();
  }

  /// Called on user interaction. Resets the timer if [isPlaying] is true.
  void onInteraction(bool isPlaying) {
    if (!state) {
      state = true;
    }
    
    if (isPlaying) {
      _startTimer();
    } else {
      // If paused, we don't start the timer, but we should cancel any existing one
      // to keep controls visible indefinitely.
      _hideTimer?.cancel();
    }
  }

  void _startTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      state = false;
    });
  }
}

/// Global provider for player UI visibility state.
/// Modifier .autoDispose is applied here only.
final playerUIProvider = NotifierProvider.autoDispose<PlayerUINotifier, bool>(() {
  return PlayerUINotifier();
});
