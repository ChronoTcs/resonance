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
    
    // For Android 13+, we need notification permission for the player
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

    // Storage/Audio Access
    if (sdkInt >= 33) {
      final status = await Permission.audio.status;
      if (!status.isGranted) {
        if (!context.mounted) return;
        final proceed = await showRationaleDialog(
          context: context,
          icon: UIcons.regular.headphones,
          title: 'Audio Access',
          message: 'Resonance needs access to your audio files to play music from your device storage.',
        );
        if (!context.mounted) return;
        if (proceed) {
          await Permission.audio.request();
        }
      }
    } else if (sdkInt >= 30) {
      // Android 11 & 12: READ_EXTERNAL_STORAGE as normal popup (not settings redirect)
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        if (!context.mounted) return;
        final proceed = await showRationaleDialog(
          context: context,
          icon: UIcons.regular.folder,
          title: 'Storage Access',
          message: 'Resonance needs access to your storage to scan your music library and manage downloads.',
        );
        if (!context.mounted) return;
        if (proceed) {
          await Permission.storage.request();
        }
      }
    } else {
      // Android 10 and below
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        if (!context.mounted) return;
        final proceed = await showRationaleDialog(
          context: context,
          icon: UIcons.regular.hdd,
          title: 'Storage Access',
          message: 'Resonance needs access to your storage to play and download music.',
        );
        if (!context.mounted) return;
        if (proceed) {
          await Permission.storage.request();
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
      final result = await Permission.requestInstallPackages.request();
      return result.isGranted;
    }

    return false;
  }

  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    // delegate to download permissions — same logic
    return requestDownloadPermissions();
  }

  /// Request essential permissions for downloading (specifically for Android storage).
  /// Replaces the manual logic previously in DownloadNotifier.
  static Future<bool> requestDownloadPermissions() async {
    if (!Platform.isAndroid) return true;

    final sdkInt = await getAndroidSdkInt();

    // Android 13+ (API 33+): MediaStore handles writes — no explicit permission needed
    if (sdkInt >= 33) return true;

    // Android 11–12 (API 30–32): READ_EXTERNAL_STORAGE only
    if (sdkInt >= 30) {
      var status = await Permission.storage.status;
      if (!status.isGranted) status = await Permission.storage.request();
      return status.isGranted;
    }

    // Android 9–10 (API 28–29): both READ + WRITE
    var readStatus = await Permission.storage.status;
    if (!readStatus.isGranted) readStatus = await Permission.storage.request();
    return readStatus.isGranted;
  }

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
