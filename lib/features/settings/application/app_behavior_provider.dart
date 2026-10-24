import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/core/data/services/windows_startup_service.dart';

class AppBehaviorState {
  final bool autoStartOnBoot;
  final bool closeToTray;
  final bool autoUpdate;
  final bool deepQueuePrefetch;

  const AppBehaviorState({
    this.autoStartOnBoot = false,
    this.closeToTray = true,
    this.autoUpdate = true,
    this.deepQueuePrefetch = true,
  });

  AppBehaviorState copyWith({
    bool? autoStartOnBoot,
    bool? closeToTray,
    bool? autoUpdate,
    bool? deepQueuePrefetch,
  }) {
    return AppBehaviorState(
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      closeToTray: closeToTray ?? this.closeToTray,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      deepQueuePrefetch: deepQueuePrefetch ?? this.deepQueuePrefetch,
    );
  }
}

class AppBehaviorNotifier extends Notifier<AppBehaviorState> {
  static const String _kAutoStartKey = 'app_behavior_auto_start';
  static const String _kCloseToTrayKey = 'app_behavior_close_to_tray';
  static const String _kAutoUpdateKey = 'app_behavior_auto_update';
  static const String _kDeepQueuePrefetchKey = 'app_behavior_deep_queue_prefetch';

  @override
  AppBehaviorState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final autoStart = prefs.getBool(_kAutoStartKey) ?? false;
    final closeToTray = prefs.getBool(_kCloseToTrayKey) ?? (Platform.isWindows ? true : false);
    final autoUpdate = prefs.getBool(_kAutoUpdateKey) ?? true;
    final deepQueuePrefetch = prefs.getBool(_kDeepQueuePrefetchKey) ?? true;

    _syncStartupRegistry(autoStart);

    return AppBehaviorState(
      autoStartOnBoot: autoStart,
      closeToTray: closeToTray,
      autoUpdate: autoUpdate,
      deepQueuePrefetch: deepQueuePrefetch,
    );
  }

  Future<void> _syncStartupRegistry(bool autoStart) async {
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
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kAutoStartKey, value);

    if (value) {
      await WindowsStartupService.enableStartup();
    } else {
      await WindowsStartupService.disableStartup();
    }
  }

  Future<void> setCloseToTray(bool value) async {
    state = state.copyWith(closeToTray: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kCloseToTrayKey, value);
  }

  Future<void> setAutoUpdate(bool value) async {
    state = state.copyWith(autoUpdate: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kAutoUpdateKey, value);
  }

  Future<void> setDeepQueuePrefetch(bool value) async {
    state = state.copyWith(deepQueuePrefetch: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kDeepQueuePrefetchKey, value);
  }
}

final appBehaviorProvider =
    NotifierProvider<AppBehaviorNotifier, AppBehaviorState>(() {
  return AppBehaviorNotifier();
});
