import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef KeyEventHandler = bool Function(
  LogicalKeyboardKey key, {
  required bool isControl,
  required bool isShift,
  required bool isInputFocused,
});

class KeyboardListenerWrapper extends StatefulWidget {
  final Widget child;
  final KeyEventHandler onKeyEvent;

  const KeyboardListenerWrapper({
    super.key,
    required this.child,
    required this.onKeyEvent,
  });

  @override
  State<KeyboardListenerWrapper> createState() => _KeyboardListenerWrapperState();
}

class _KeyboardListenerWrapperState extends State<KeyboardListenerWrapper> {
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

    final focusWidget = focusNode.context!.widget;
    if (focusWidget is EditableText) {
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
    final isInputFocused = _isInputFocused();

    return widget.onKeyEvent(
      key,
      isControl: isControl,
      isShift: isShift,
      isInputFocused: isInputFocused,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
