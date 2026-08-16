import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists window size and position to SharedPreferences on resize/move.
/// Must be added as a [WindowListener] and disposed with the owning widget.
class WindowPersistenceService extends WindowListener {
  final WidgetRef _ref;

  WindowPersistenceService(this._ref);

  @override
  void onWindowFocus() {
    // Re-present Direct3D 11 swapchain immediately when the user clicks/focuses the window
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void onWindowRestore() {
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void onWindowResized() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    final popState = _ref.read(miniPlayerPopProvider);
    if (popState.isPopped) return;

    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  }

  @override
  void onWindowMoved() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    final popState = _ref.read(miniPlayerPopProvider);
    if (popState.isPopped) return;

    final pos = await windowManager.getPosition();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_x', pos.dx);
    await prefs.setDouble('window_y', pos.dy);
  }

  @override
  void onWindowClose() async {
    if (Platform.isWindows) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }
}

/// Global window style listener (fullscreen, restore).
class AppWindowStyleListener extends WindowListener {
  @override
  void onWindowLeaveFullScreen() {
    windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void onWindowRestore() {
    windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void onWindowFocus() {
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }
}
