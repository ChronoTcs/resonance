import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/application/providers/window_lifecycle_provider.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';
import 'package:resonance/features/tray/application/tray_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists window size and position to SharedPreferences on resize/move.
/// Must be added as a [WindowListener] and disposed with the owning widget.
class WindowPersistenceService extends WindowListener {
  final WidgetRef _ref;

  WindowPersistenceService(this._ref);

  @override
  void onWindowMinimize() {
    _ref.read(isWindowRenderActiveProvider.notifier).state = false;
  }

  @override
  void onWindowFocus() {
    // Re-present Direct3D 11 swapchain immediately when the user clicks/focuses the window
    WidgetsBinding.instance.scheduleWarmUpFrame();
  }

  @override
  void onWindowRestore() {
    _ref.read(isWindowRenderActiveProvider.notifier).state = true;
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
      final closeToTray = _ref.read(appBehaviorProvider).closeToTray;
      if (closeToTray) {
        _ref.read(isWindowRenderActiveProvider.notifier).state = false;
        await windowManager.hide();
      } else {
        await _ref.read(trayServiceProvider).handleExit();
      }
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
    windowManager.setMinimumSize(const Size(800, 600));
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
