import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/features/download/application/download_service.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/settings/application/update_provider.dart';

/// Runs one-time startup checks after first frame: update detection, notification init.
/// Call from a `WidgetsBinding.instance.addPostFrameCallback` in the root widget's initState.
Future<void> runStartupChecks(WidgetRef ref) async {
  // Initialise notification provider (lazy singleton bootstrap)
  ref.read(notificationProvider);

  // Pre-warm the DownloaderBridge Python process so it's ready before the user
  // navigates to the Download page or triggers stream URL resolution.
  // downloadServiceProvider is lazy by default — read here to boot it at startup.
  ref.read(downloadServiceProvider);

  // Fetch remote app config asynchronously (URLs, donate link, bug report URL)
  ref.read(appConfigProvider.notifier).fetchRemoteConfig().ignore();

  // Auto update check
  try {
    final updateNotifier = ref.read(updateProvider.notifier);
    await updateNotifier.checkForUpdate();
    final updateState = ref.read(updateProvider);
    if (updateState.updateAvailable) {
      ref.read(notificationProvider.notifier).showNotification(
        'Update Available',
        'A new version (${updateState.latestVersion}) is available. Click to download.',
        target: 'target:settings',
      );
    }
  } catch (e) {
    debugPrint('Startup update check failed: $e');
  }
}
