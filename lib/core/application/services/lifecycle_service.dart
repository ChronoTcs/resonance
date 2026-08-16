import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/data_usage_service.dart';
import 'package:resonance/core/data/services/po_token_provider_service.dart';

/// Manages app lifecycle events: flushes data on pause/hide/detach,
/// and stops background services on dispose.
class AppLifecycleService {
  final WidgetRef _ref;
  late final AppLifecycleListener _listener;

  AppLifecycleService(this._ref) {
    _listener = AppLifecycleListener(
      onResume: () {
        // Force immediate DirectX 11 / DWM swapchain refresh upon waking from idle/sleep
        WidgetsBinding.instance.scheduleWarmUpFrame();
      },
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          WidgetsBinding.instance.scheduleWarmUpFrame();
        } else if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          _ref.read(dataUsageServiceProvider).flush();
        }
      },
    );
  }

  void dispose() {
    poTokenProviderService.stop();
    _listener.dispose();
  }
}
