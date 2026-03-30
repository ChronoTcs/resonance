import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/player/application/audio_provider.dart';
import 'package:resonance_app/features/player/application/video_player_notifier.dart';
import 'package:resonance_app/features/player/application/active_media_focus_provider.dart';

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

    // 1. Cek langsung widgetnya (berjaga-jaga)
    final widget = focusNode.context!.widget;
    if (widget is EditableText || widget is TextField || widget is TextFormField) {
      return true;
    }

    // 2. Teknik Tree Traversal: Memanjat pohon widget ke atas untuk mencari induknya
    focusNode.context!.visitAncestorElements((element) {
      if (element.widget is EditableText || 
          element.widget is TextField || 
          element.widget is TextFormField) {
        isTextInput = true;
        return false; // Berhenti memanjat, kita sudah menemukannya!
      }
      return true; // Terus memanjat ke atas
    });

    return isTextInput;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    final focus = ref.read(mediaFocusProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    // 1. Space Logic (Play/Pause)
    if (key == LogicalKeyboardKey.space) {
      if (_isInputFocused()) {
        return false;
      }
      if (focus == MediaFocus.video) {
        videoNotifier.togglePlayPause();
      } else {
        audioNotifier.togglePlayPause();
      }
      return true;
    }

    // 2. Ctrl + ArrowRight/Left (Next/Prev)
    if (isControl) {
      if (key == LogicalKeyboardKey.arrowRight) {
        if (focus == MediaFocus.audio) audioNotifier.skipToNext();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (focus == MediaFocus.audio) audioNotifier.skipToPrevious();
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
        if (focus == MediaFocus.audio) {
          audioNotifier.adjustPosition(const Duration(seconds: 10));
        }
        return true;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (focus == MediaFocus.audio) {
          audioNotifier.adjustPosition(const Duration(seconds: -10));
        }
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
