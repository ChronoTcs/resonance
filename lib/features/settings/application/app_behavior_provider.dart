import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance/core/data/services/windows_startup_service.dart';

class AppBehaviorState {
  final bool autoStartOnBoot;
  final bool closeToTray;
  final bool autoUpdate;

  const AppBehaviorState({
    this.autoStartOnBoot = false,
    this.closeToTray = true,
    this.autoUpdate = true,
  });

  AppBehaviorState copyWith({
    bool? autoStartOnBoot,
    bool? closeToTray,
    bool? autoUpdate,
  }) {
    return AppBehaviorState(
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      closeToTray: closeToTray ?? this.closeToTray,
      autoUpdate: autoUpdate ?? this.autoUpdate,
    );
  }
}

class AppBehaviorNotifier extends Notifier<AppBehaviorState> {
  static const String _kAutoStartKey = 'app_behavior_auto_start';
  static const String _kCloseToTrayKey = 'app_behavior_close_to_tray';
  static const String _kAutoUpdateKey = 'app_behavior_auto_update';

  @override
  AppBehaviorState build() {
    _loadSettings();
    return const AppBehaviorState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final autoStart = prefs.getBool(_kAutoStartKey) ?? false;
    final closeToTray = prefs.getBool(_kCloseToTrayKey) ?? true;
    final autoUpdate = prefs.getBool(_kAutoUpdateKey) ?? true;

    state = AppBehaviorState(
      autoStartOnBoot: autoStart,
      closeToTray: closeToTray,
      autoUpdate: autoUpdate,
    );

    // Sync registry status on startup
    final registryEnabled = await WindowsStartupService.isEnabled();
    if (registryEnabled != autoStart) {
      if (autoStart) {
        await WindowsStartupService.enableStartup();
      } else {
        await WindowsStartupService.disableStartup();
      }
    }
  }

  Future<void> setAutoStartOnBoot(bool value) async {
    state = state.copyWith(autoStartOnBoot: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoStartKey, value);

    if (value) {
      await WindowsStartupService.enableStartup();
    } else {
      await WindowsStartupService.disableStartup();
    }
  }

  Future<void> setCloseToTray(bool value) async {
    state = state.copyWith(closeToTray: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCloseToTrayKey, value);
  }

  Future<void> setAutoUpdate(bool value) async {
    state = state.copyWith(autoUpdate: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoUpdateKey, value);
  }
}

final appBehaviorProvider =
    NotifierProvider<AppBehaviorNotifier, AppBehaviorState>(() {
  return AppBehaviorNotifier();
});
