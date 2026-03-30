import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/permission_service.dart';

class UpdateState {
  final bool isChecking;
  final bool updateAvailable;
  final String latestVersion;
  final String changelog;
  final double downloadProgress;
  final bool isDownloading;
  final String? error;
  final List<dynamic>? assets;

  UpdateState({
    this.isChecking = false,
    this.updateAvailable = false,
    this.latestVersion = '',
    this.changelog = '',
    this.downloadProgress = 0.0,
    this.isDownloading = false,
    this.error,
    this.assets,
  });

  UpdateState copyWith({
    bool? isChecking,
    bool? updateAvailable,
    String? latestVersion,
    String? changelog,
    double? downloadProgress,
    bool? isDownloading,
    String? error,
    List<dynamic>? assets,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      latestVersion: latestVersion ?? this.latestVersion,
      changelog: changelog ?? this.changelog,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      error: error,
      assets: assets ?? this.assets,
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => UpdateState();

  final Dio _dio = Dio();

  Future<void> checkForUpdate() async {
    state = state.copyWith(isChecking: true, error: null);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(
        'https://api.github.com/repos/ChronoTechs/resonance/releases/latest',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = data['tag_name'].toString().replaceAll('v', '');
        final changelog = data['body'] ?? 'No changelog provided.';
        final assets = data['assets'] as List<dynamic>;

        final isAvailable = _isVersionNewer(currentVersion, latestVersion);

        state = state.copyWith(
          isChecking: false,
          updateAvailable: isAvailable,
          latestVersion: latestVersion,
          changelog: changelog,
          assets: assets,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // GitHub returns 404 if there are no releases yet
        state = state.copyWith(
          isChecking: false, 
          updateAvailable: false,
          latestVersion: '0.0.0',
          changelog: 'No releases found on GitHub.',
        );
      } else {
        state = state.copyWith(isChecking: false, error: e.message ?? e.toString());
      }
    } catch (e) {
      state = state.copyWith(isChecking: false, error: e.toString());
    }
  }

  Future<void> downloadUpdate() async {
    if (state.assets == null || state.assets!.isEmpty) return;

    state = state.copyWith(isDownloading: true, downloadProgress: 0.0, error: null);

    try {
      String? downloadUrl;
      String? fileName;

      for (var asset in state.assets!) {
        final name = asset['name'].toString().toLowerCase();
        if (Platform.isAndroid && name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'];
          fileName = asset['name'];
          break;
        } else if (Platform.isWindows && name.endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'];
          fileName = asset['name'];
          break;
        }
      }

      if (downloadUrl == null) {
        state = state.copyWith(isDownloading: false, error: 'Appropriate update asset not found.');
        return;
      }

      final directory = Platform.isAndroid 
          ? await getTemporaryDirectory() 
          : await getDownloadsDirectory() ?? await getTemporaryDirectory();
      
      final filePath = '${directory.path}/$fileName';

      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            state = state.copyWith(downloadProgress: count / total);
          }
        },
      );

      state = state.copyWith(isDownloading: false, downloadProgress: 1.0);
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }

  Future<void> installUpdate(BuildContext context) async {
    if (state.assets == null || state.assets!.isEmpty) return;
    
    // Find the downloaded file path
    String? fileName;
    for (var asset in state.assets!) {
      final name = asset['name'].toString().toLowerCase();
      if ((Platform.isAndroid && name.endsWith('.apk')) || 
          (Platform.isWindows && name.endsWith('.exe'))) {
        fileName = asset['name'];
        break;
      }
    }
    
    if (fileName == null) return;

    final directory = Platform.isAndroid 
        ? await getTemporaryDirectory() 
        : await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';

    if (!await File(filePath).exists()) {
      state = state.copyWith(error: 'Installation file not found. Please download again.');
      return;
    }

    try {
      if (Platform.isAndroid) {
        // --- NEW: Check for Install Packages Permission ---
        final hasPermission = await PermissionService.checkAndRequestInstallPermission(context);
        if (!hasPermission) {
          state = state.copyWith(error: 'Permission to install unknown apps was denied.');
          return;
        }
        
        await OpenFilex.open(filePath);
      } else if (Platform.isWindows) {
        await Process.start(
          filePath, 
          ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/FORCECLOSEAPPLICATIONS'],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to launch installer: $e');
    }
  }

  bool _isVersionNewer(String current, String latest) {
    try {
      final currentClean = current.split('+')[0];
      final latestClean = latest.split('+')[0];
      
      final currentParts = currentClean.split('.').map(int.parse).toList();
      final latestParts = latestClean.split('.').map(int.parse).toList();

      for (var i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return latest != current;
    }
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});
