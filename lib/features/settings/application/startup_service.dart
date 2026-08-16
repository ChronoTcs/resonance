import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/download/application/download_service.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/settings/application/update_provider.dart';

/// Runs startup checks: update detection, auto-update staging, notification init, and offline gating.
/// Supports both WidgetRef (UI initState) and Ref (background services).
Future<void> runStartupChecks(dynamic ref, {bool? isOnline}) async {
  // Determine online state without self-dependency if already known
  bool online = isOnline ?? true;
  if (isOnline == null) {
    try {
      final connectivityNotifier = ref.read(networkConnectivityProvider.notifier);
      online = await (connectivityNotifier as NetworkConnectivityNotifier).checkConnectivity();
    } catch (_) {
      try {
        final connectivity = ref.read(networkConnectivityProvider);
        online = (connectivity as NetworkConnectivityState).isOnline;
      } catch (_) {
        online = true;
      }
    }
  }

  // Initialise notification provider (lazy singleton bootstrap)
  ref.read(notificationProvider);

  // Pre-warm the DownloaderBridge Python process
  ref.read(downloadServiceProvider);

  // If offline, suppress network calls — connectivity service will auto-trigger on reconnection
  if (!online) {
    debugPrint('[StartupService] Device is offline. Suppressing startup network calls until reconnected.');
    return;
  }

  // Fetch remote app config asynchronously (URLs, donate link, bug report URL)
  unawaited(ref.read(appConfigProvider.notifier).fetchRemoteConfig());

  // Auto update check & auto-update staging
  try {
    final updateNotifier = ref.read(updateProvider.notifier);
    await updateNotifier.checkForUpdate();
    final updateState = ref.read(updateProvider);
    if (updateState.updateAvailable && updateState.latestRelease != null) {
      final appBehavior = ref.read(appBehaviorProvider);
      if (appBehavior.autoUpdate) {
        debugPrint('[StartupService] Auto-update is ON. Initiating silent background staging for v${updateState.latestVersion}...');
        unawaited(updateNotifier.downloadRelease(updateState.latestRelease!).then((_) {
          final newState = ref.read(updateProvider);
          if (newState.isUpdateReadyToRestart) {
            ref.read(notificationProvider.notifier).showNotification(
              'Update Ready to Install',
              'Resonance v${updateState.latestVersion} has been downloaded. Restart app to apply.',
              target: 'target:settings',
            );
          }
        }));
      } else {
        ref.read(notificationProvider.notifier).showNotification(
          'Update Available',
          'A new version (${updateState.latestVersion}) is available. Click to download.',
          target: 'target:settings',
        );
      }
    }
  } catch (e) {
    debugPrint('[StartupService] Startup update check failed: $e');
  }
}
