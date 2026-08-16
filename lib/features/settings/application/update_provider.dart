import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resonance/core/constants/app_constants.dart';
import 'package:resonance/core/application/services/delta_update_service.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/application/services/permission_service.dart';
import '../data/models/release_model.dart';

const _kDownloadedTag = 'update_downloaded_tag';
const _kDownloadedPath = 'update_downloaded_path';
const _kStagedVersionTag = 'update_staged_version';

class UpdateState {
  final bool isChecking;
  final String currentVersion;
  final List<AppRelease> releases;
  final AppRelease? selectedRelease;
  final double downloadProgress;
  final bool isDownloading;
  final bool isPatching;
  final bool isUpdateReadyToRestart;
  final String? stagedVersion;
  final String? error;

  UpdateState({
    this.isChecking = false,
    this.currentVersion = '',
    this.releases = const [],
    this.selectedRelease,
    this.downloadProgress = 0.0,
    this.isDownloading = false,
    this.isPatching = false,
    this.isUpdateReadyToRestart = false,
    this.stagedVersion,
    this.error,
  });

  AppRelease? get latestRelease => releases.isNotEmpty ? releases.first : null;
  List<AppRelease> get olderReleases => releases.length > 1 ? releases.sublist(1) : [];

  bool get updateAvailable => latestRelease != null && latestRelease!.isNewerThanCurrent;
  String get latestVersion => latestRelease?.tagName ?? '';
  String get changelog => latestRelease?.body ?? '';

  UpdateState copyWith({
    bool? isChecking,
    String? currentVersion,
    List<AppRelease>? releases,
    AppRelease? selectedRelease,
    double? downloadProgress,
    bool? isDownloading,
    bool? isPatching,
    bool? isUpdateReadyToRestart,
    String? stagedVersion,
    String? error,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      currentVersion: currentVersion ?? this.currentVersion,
      releases: releases ?? this.releases,
      selectedRelease: selectedRelease ?? this.selectedRelease,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      isPatching: isPatching ?? this.isPatching,
      isUpdateReadyToRestart: isUpdateReadyToRestart ?? this.isUpdateReadyToRestart,
      stagedVersion: stagedVersion ?? this.stagedVersion,
      error: error,
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    _initPendingCheck();
    return UpdateState();
  }

  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  Future<void> _initPendingCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStagedTag = prefs.getString(_kStagedVersionTag);
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (savedStagedTag != null) {
      // If currently running version already matches or exceeds the staged version, clear the flag and staging folder!
      if (AppRelease.compareSemVer(currentVersion, savedStagedTag) >= 0) {
        await prefs.remove(_kStagedVersionTag);
        await prefs.remove(_kDownloadedTag);
        await prefs.remove(_kDownloadedPath);
        await ref.read(deltaUpdateServiceProvider).clearStagingDirectory();
        state = state.copyWith(
          isUpdateReadyToRestart: false,
          stagedVersion: null,
        );
        return;
      }

      final hasPending = await ref.read(deltaUpdateServiceProvider).hasPendingStagedUpdate();
      if (hasPending) {
        state = state.copyWith(
          isUpdateReadyToRestart: true,
          stagedVersion: savedStagedTag,
        );
      } else {
        // Staging directory does not exist on disk -> clear phantom preference!
        await prefs.remove(_kStagedVersionTag);
        state = state.copyWith(
          isUpdateReadyToRestart: false,
          stagedVersion: null,
        );
      }
    }
  }

  Future<void> fetchReleases() async {
    // Skip network request immediately if device is offline
    if (!ref.read(networkConnectivityProvider).isOnline) {
      debugPrint('[UpdateNotifier] Device offline — skipping release check.');
      state = state.copyWith(isChecking: false);
      return;
    }

    state = state.copyWith(isChecking: true, error: null);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final options = Options(
        headers: {
          'User-Agent': 'ResonanceApp',
          'Accept': 'application/vnd.github+json',
        },
      );

      List<dynamic> data = [];
      try {
        final response = await _dio.get(
          AppConstants.githubReleasesApiUrl,
          options: options,
        );
        if (response.statusCode == 200 && response.data is List) {
          data = response.data as List<dynamic>;
        }
      } catch (e) {
        debugPrint('[UpdateNotifier] List releases failed, trying latest: $e');
      }

      // Fallback to /releases/latest if list endpoint is empty
      if (data.isEmpty) {
        try {
          final latestResponse = await _dio.get(
            '${AppConstants.githubReleasesApiUrl}/latest',
            options: options,
          );
          if (latestResponse.statusCode == 200 && latestResponse.data is Map) {
            data = [latestResponse.data];
          }
        } catch (e) {
          debugPrint('[UpdateNotifier] Latest release fetch failed: $e');
        }
      }

      final parsedReleases = data
          .map((json) => AppRelease.fromJson(json as Map<String, dynamic>, currentVersion))
          .toList();

      state = state.copyWith(
        isChecking: false,
        currentVersion: currentVersion,
        releases: parsedReleases,
        error: parsedReleases.isEmpty ? 'No releases found on GitHub.' : null,
      );
      if (parsedReleases.isNotEmpty) {
        await _checkExistingDownload(parsedReleases);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(
          isChecking: false,
          releases: [],
          error: 'No releases found on GitHub.',
        );
      } else {
        state = state.copyWith(isChecking: false, error: e.message ?? e.toString());
      }
    } catch (e) {
      state = state.copyWith(isChecking: false, error: e.toString());
    }
  }

  Future<void> checkForUpdate() => fetchReleases();

  Future<void> downloadRelease(AppRelease release) async {
    if (release.assets.isEmpty) {
      state = state.copyWith(error: 'No download assets attached to this release.');
      return;
    }

    _cancelToken = CancelToken();
    state = state.copyWith(
      selectedRelease: release,
      isDownloading: true,
      isPatching: false,
      downloadProgress: 0.0,
      error: null,
    );

    try {
      // 1. Try Discord-style Delta Patching on Windows first
      final deltaAsset = Platform.isWindows ? release.getDeltaPatchAsset(state.currentVersion) : null;
      if (deltaAsset != null) {
        final deltaUrl = deltaAsset['browser_download_url'] as String?;
        final patchName = deltaAsset['name'] as String?;

        if (deltaUrl != null && patchName != null) {
          debugPrint('[UpdateNotifier] Found delta patch asset: $patchName (~${((deltaAsset['size'] ?? 0) / 1024 / 1024).toStringAsFixed(1)} MB). Downloading...');
          
          final deltaService = ref.read(deltaUpdateServiceProvider);
          final downloadedPatch = await deltaService.downloadDeltaPatch(
            downloadUrl: deltaUrl,
            fileName: patchName,
            cancelToken: _cancelToken,
            onProgress: (prog) => state = state.copyWith(downloadProgress: prog),
          );

          if (downloadedPatch != null && await downloadedPatch.exists()) {
            state = state.copyWith(isPatching: true, downloadProgress: 1.0);
            final stagedOk = await deltaService.applyPatchAndStage(
              patchFile: downloadedPatch,
              targetVersion: release.tagName,
            );

            if (stagedOk) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kStagedVersionTag, release.tagName);
              state = state.copyWith(
                isDownloading: false,
                isPatching: false,
                isUpdateReadyToRestart: true,
                stagedVersion: release.tagName,
                downloadProgress: 1.0,
              );
              return;
            }
          }
          debugPrint('[UpdateNotifier] Delta patch application failed or patcher missing. Falling back to full installer...');
        }
      }

      // 2. Standard Fallback to Full Installer (.exe / .apk)
      String? downloadUrl;
      String? fileName;

      for (var asset in release.assets) {
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
        state = state.copyWith(
          isDownloading: false,
          isPatching: false,
          error: 'Compatible installer (${Platform.isWindows ? ".exe" : ".apk"}) not found in release assets.',
        );
        return;
      }

      final directory = Platform.isAndroid
          ? await getTemporaryDirectory()
          : await getDownloadsDirectory() ?? await getTemporaryDirectory();

      final filePath = '${directory.path}/$fileName';

      await _dio.download(
        downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            state = state.copyWith(downloadProgress: count / total);
          }
        },
      );

      // Persist download so Install button survives app restart
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDownloadedTag, release.tagName);
      await prefs.setString(_kDownloadedPath, filePath);

      state = state.copyWith(isDownloading: false, isPatching: false, downloadProgress: 1.0);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state = state.copyWith(isDownloading: false, isPatching: false, downloadProgress: 0.0, error: null);
      } else {
        state = state.copyWith(isDownloading: false, isPatching: false, error: e.message ?? e.toString());
      }
    } catch (e) {
      state = state.copyWith(isDownloading: false, isPatching: false, error: e.toString());
    } finally {
      _cancelToken = null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
  }

  /// Deletes the downloaded installer/staged files from disk and resets download state.
  Future<void> deleteDownloadedRelease(AppRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_kDownloadedPath);

    if (savedPath != null && File(savedPath).existsSync()) {
      try {
        await File(savedPath).delete();
      } catch (e) {
        debugPrint('[UpdateNotifier] Failed to delete installer: $e');
      }
    } else {
      String? fileName;
      for (var asset in release.assets) {
        final name = asset['name'].toString().toLowerCase();
        if ((Platform.isAndroid && name.endsWith('.apk')) ||
            (Platform.isWindows && name.endsWith('.exe'))) {
          fileName = asset['name'];
          break;
        }
      }
      if (fileName != null) {
        final directory = Platform.isAndroid
            ? await getTemporaryDirectory()
            : await getDownloadsDirectory() ?? await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        if (File(filePath).existsSync()) {
          try {
            await File(filePath).delete();
          } catch (_) {}
        }
      }
    }

    await prefs.remove(_kDownloadedTag);
    await prefs.remove(_kDownloadedPath);
    await prefs.remove(_kStagedVersionTag);
    await ref.read(deltaUpdateServiceProvider).clearStagingDirectory();

    state = state.copyWith(
      downloadProgress: 0.0,
      selectedRelease: null,
      isUpdateReadyToRestart: false,
      stagedVersion: null,
    );
  }

  /// On startup: restore downloaded/staged state
  Future<void> _checkExistingDownload(List<AppRelease> releases) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTag = prefs.getString(_kDownloadedTag);
    final savedPath = prefs.getString(_kDownloadedPath);
    final savedStaged = prefs.getString(_kStagedVersionTag);

    if (savedStaged != null) {
      if (AppRelease.compareSemVer(state.currentVersion, savedStaged) >= 0) {
        await prefs.remove(_kStagedVersionTag);
        await prefs.remove(_kDownloadedTag);
        await prefs.remove(_kDownloadedPath);
        await ref.read(deltaUpdateServiceProvider).clearStagingDirectory();
        state = state.copyWith(isUpdateReadyToRestart: false, stagedVersion: null);
        return;
      }

      final hasPending = await ref.read(deltaUpdateServiceProvider).hasPendingStagedUpdate();
      if (!hasPending) {
        await prefs.remove(_kStagedVersionTag);
        state = state.copyWith(isUpdateReadyToRestart: false, stagedVersion: null);
        return;
      }

      state = state.copyWith(
        isUpdateReadyToRestart: true,
        stagedVersion: savedStaged,
      );
      return;
    }

    if (savedTag == null || savedPath == null) return;

    if (!File(savedPath).existsSync()) {
      await prefs.remove(_kDownloadedTag);
      await prefs.remove(_kDownloadedPath);
      return;
    }

    final match = releases.where((r) => r.tagName == savedTag).firstOrNull;
    if (match == null) return;

    state = state.copyWith(
      selectedRelease: match,
      downloadProgress: 1.0,
    );
  }

  Future<void> downloadUpdate() async {
    if (state.latestRelease != null) {
      await downloadRelease(state.latestRelease!);
    }
  }

  /// 1-Second Instant Restart applying the staged delta update
  Future<void> applyAndRestart() async {
    await ref.read(deltaUpdateServiceProvider).executeInstantRestart();
  }

  Future<void> installRelease(BuildContext context, AppRelease release) async {
    // If a staged delta update is ready, perform 1-second instant restart
    if (state.isUpdateReadyToRestart) {
      await applyAndRestart();
      return;
    }

    if (release.assets.isEmpty) return;

    String? fileName;
    for (var asset in release.assets) {
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
        if (!context.mounted) return;
        final hasPermission = await PermissionService.checkAndRequestInstallPermission(context);
        if (!hasPermission) {
          state = state.copyWith(error: 'Permission to install unknown apps was denied.');
          return;
        }

        await OpenFilex.open(filePath);
      } else if (Platform.isWindows) {
        await Process.start(
          filePath,
          ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/FORCECLOSEAPPLICATIONS', '/RELAUNCH=1'],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to launch installer: $e');
    }
  }

  Future<void> installUpdate(BuildContext context) async {
    if (state.isUpdateReadyToRestart) {
      await applyAndRestart();
    } else if (state.selectedRelease != null) {
      await installRelease(context, state.selectedRelease!);
    } else if (state.latestRelease != null) {
      await installRelease(context, state.latestRelease!);
    }
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});
