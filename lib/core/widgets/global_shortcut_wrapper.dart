import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class GlobalShortcutWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalShortcutWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalShortcutWrapper> createState() => _GlobalShortcutWrapperState();
}

class _GlobalShortcutWrapperState extends ConsumerState<GlobalShortcutWrapper> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _isInputFocused() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null || focusNode.context == null) return false;

    bool isTextInput = false;

    final widget = focusNode.context!.widget;
    if (widget is EditableText) {
      return true;
    }

    focusNode.context!.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        isTextInput = true;
        return false;
      }
      return true;
    });

    return isTextInput;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    final audioNotifier = ref.read(audioProvider.notifier);

    // 1. Space Logic (Play/Pause)
    if (key == LogicalKeyboardKey.space) {
      if (_isInputFocused()) {
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
        ref.read(audioProvider.notifier).adjustVolume(5.0);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        ref.read(audioProvider.notifier).adjustVolume(-5.0);
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

    return false; // Event not handled
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
