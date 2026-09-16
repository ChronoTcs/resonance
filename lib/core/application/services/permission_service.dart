import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';

class PermissionService {
  /// Shows a clean rationale dialog before requesting a permission.
  static Future<bool> showRationaleDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NOT NOW'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> requestInitialPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final sdkInt = await getAndroidSdkInt();
    
    // For Android 13+, request notification permission for the foreground media player controls
    if (sdkInt >= 33) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        if (!context.mounted) return;
        final proceed = await showRationaleDialog(
          context: context,
          icon: UIcons.regular.bell,
          title: 'Notifications',
          message: 'Resonance needs notification permission to show the music player controls in your notification bar.',
        );
        if (!context.mounted) return;
        if (proceed) {
          await Permission.notification.request();
        }
      }
    }
  }

  /// Specialized check for APK installation permission (Android 8.0+)
  static Future<bool> checkAndRequestInstallPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // REQUEST_INSTALL_PACKAGES is for Android 8.0 (API 26) and above
    final status = await Permission.requestInstallPackages.status;
    
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    // Show rationale because this leads to a dangerous system setting page
    final proceed = await showRationaleDialog(
      context: context,
      icon: UIcons.regular.shield,
      title: 'Install Unknown Apps',
      message: 'To install the update, Resonance needs your permission to "Install Unknown Apps". You will be redirected to the system settings to enable this for Resonance.',
    );

    if (!context.mounted) return false;

    if (proceed) {
      await Permission.requestInstallPackages.request();
      // Re-read fresh status after returning from system settings
      final fresh = await Permission.requestInstallPackages.status;
      return fresh.isGranted;
    }

    return false;
  }

  /// Returns current install-packages permission status without showing any UI.
  /// Use this to re-verify after returning from Android Settings.
  static Future<bool> checkInstallPermissionStatus() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.status;
    return status.isGranted;
  }

  /// Scoped storage / SAF are used for downloads and caching. No legacy storage permission required.
  static Future<bool> requestStoragePermission() async => true;

  /// Downloads write directly to app-specific storage or SAF URI grants.
  static Future<bool> requestDownloadPermissions() async => true;

  static Future<int> getAndroidSdkInt() async {
    try {
      if (Platform.isAndroid) {
        final versionString = Platform.operatingSystemVersion;
        final match = RegExp(r'SDK\s+(\d+)').firstMatch(versionString);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      }
    } catch (_) {}
    return 33; // Fallback
  }
}
