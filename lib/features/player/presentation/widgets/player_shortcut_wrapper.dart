import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class PlayerShortcutWrapper extends ConsumerWidget {
  final Widget child;

  const PlayerShortcutWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KeyboardListenerWrapper(
      onKeyEvent: (key, {required isControl, required isShift, required isInputFocused}) {
        final audioNotifier = ref.read(audioProvider.notifier);

        // 1. Space Logic (Play/Pause)
        if (key == LogicalKeyboardKey.space) {
          if (isInputFocused) {
            return false;
          }
          audioNotifier.togglePlayPause();
          return true;
        }

        // 2. Ctrl + ArrowRight/Left (Next/Prev)
        if (isControl) {
          if (key == LogicalKeyboardKey.arrowRight) {
            audioNotifier.skipToNext();
            return true;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            audioNotifier.skipToPrevious();
            return true;
          }
        }

        // 3. Ctrl + ArrowUp/Down (Volume)
        if (isControl) {
          if (key == LogicalKeyboardKey.arrowUp) {
            audioNotifier.adjustVolume(5.0);
            return true;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            audioNotifier.adjustVolume(-5.0);
            return true;
          }
        }

        // 4. Shift + ArrowRight/Left (Seek)
        if (isShift) {
          if (key == LogicalKeyboardKey.arrowRight) {
            audioNotifier.adjustPosition(const Duration(seconds: 10));
            return true;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            audioNotifier.adjustPosition(const Duration(seconds: -10));
            return true;
          }
        }

        return false;
      },
      child: child,
    );
  }
}
