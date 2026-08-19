import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/data/services/cache_manager.dart';
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

  // Clean any pending deleted files from previous sessions
  unawaited(_cleanPendingDeletions(ref));

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

Future<void> _cleanPendingDeletions(dynamic ref) async {
  try {
    final cacheManager = ref.read(cacheManagerProvider);
    final musicDir = await cacheManager.getLocalMusicDir();
    final lyricsDir = await cacheManager.getLocalLyricsDir();
    final imagesDir = await cacheManager.getLocalImagesDir();

    for (final dir in [musicDir, lyricsDir, imagesDir]) {
      if (dir is Directory && await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.pending_delete')) {
            try {
              await entity.delete();
              debugPrint('[StartupService] Purged pending deleted file: ${entity.path}');
            } catch (_) {}
          }
        }
      }
    }
  } catch (_) {}
}
