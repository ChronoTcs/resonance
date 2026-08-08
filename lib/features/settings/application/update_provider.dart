import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resonance/core/constants/app_constants.dart';
import '../../../core/application/services/permission_service.dart';
import '../data/models/release_model.dart';

class UpdateState {
  final bool isChecking;
  final String currentVersion;
  final List<AppRelease> releases;
  final AppRelease? selectedRelease;
  final double downloadProgress;
  final bool isDownloading;
  final String? error;

  UpdateState({
    this.isChecking = false,
    this.currentVersion = '',
    this.releases = const [],
    this.selectedRelease,
    this.downloadProgress = 0.0,
    this.isDownloading = false,
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
    String? error,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      currentVersion: currentVersion ?? this.currentVersion,
      releases: releases ?? this.releases,
      selectedRelease: selectedRelease ?? this.selectedRelease,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      error: error,
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => UpdateState();

  final Dio _dio = Dio();

  Future<void> fetchReleases() async {
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

    state = state.copyWith(
      selectedRelease: release,
      isDownloading: true,
      downloadProgress: 0.0,
      error: null,
    );

    try {
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

  Future<void> downloadUpdate() async {
    if (state.latestRelease != null) {
      await downloadRelease(state.latestRelease!);
    }
  }

  Future<void> installRelease(BuildContext context, AppRelease release) async {
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
          ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/FORCECLOSEAPPLICATIONS'],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to launch installer: $e');
    }
  }

  Future<void> installUpdate(BuildContext context) async {
    if (state.selectedRelease != null) {
      await installRelease(context, state.selectedRelease!);
    } else if (state.latestRelease != null) {
      await installRelease(context, state.latestRelease!);
    }
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});
