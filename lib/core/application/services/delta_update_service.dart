import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:resonance/core/utils/path_utils.dart';

class DeltaPatchInfo {
  final String fromVersion;
  final String toVersion;
  final String downloadUrl;
  final int sizeBytes;
  final String? sha256;
  final bool isDirectoryPatch;

  DeltaPatchInfo({
    required this.fromVersion,
    required this.toVersion,
    required this.downloadUrl,
    required this.sizeBytes,
    this.sha256,
    this.isDirectoryPatch = true,
  });

  factory DeltaPatchInfo.fromJson(Map<String, dynamic> json, String toVersion) {
    return DeltaPatchInfo(
      fromVersion: json['from_version'] ?? '',
      toVersion: toVersion,
      downloadUrl: json['patch_url'] ?? json['browser_download_url'] ?? '',
      sizeBytes: json['size_bytes'] ?? json['size'] ?? 0,
      sha256: json['sha256'],
      isDirectoryPatch: json['is_directory_patch'] ?? true,
    );
  }
}

class DeltaUpdateService {
  final Dio _dio = Dio();

  /// Gets the current running application executable directory
  Directory get appDirectory => Directory(p.dirname(Platform.resolvedExecutable));

  /// Gets the local staging directory for background update construction
  Future<Directory> getStagingDirectory() async {
    final stagingPath = await PathUtils.getStagingDefault();
    final stagedDir = Directory(stagingPath);
    if (!await stagedDir.exists()) {
      await stagedDir.create(recursive: true);
    }
    return stagedDir;
  }

  /// Gets the path to the bundled or local hpatchz.exe binary
  Future<File?> getPatcherExecutable() async {
    final candidates = [
      p.join(appDirectory.path, 'tools', 'hpatchz.exe'),
      p.join(appDirectory.path, 'hpatchz.exe'),
      p.join(appDirectory.path, 'windows', 'tools', 'hpatchz.exe'),
    ];

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    return null;
  }

  /// Downloads the delta patch with progress tracking
  Future<File?> downloadDeltaPatch({
    required String downloadUrl,
    required String fileName,
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      final patchFilePath = p.join(tempDir.path, fileName);
      final patchFile = File(patchFilePath);

      if (await patchFile.exists()) {
        try {
          await patchFile.delete();
        } catch (_) {}
      }

      await _dio.download(
        downloadUrl,
        patchFilePath,
        cancelToken: cancelToken,
        onReceiveProgress: (count, total) {
          if (total > 0 && onProgress != null) {
            onProgress(count / total);
          }
        },
      );

      return patchFile;
    } catch (e) {
      debugPrint('[DeltaUpdateService] Download failed: $e');
      return null;
    }
  }

  /// Verifies SHA256 checksum of a file
  Future<bool> verifyChecksum(File file, String expectedSha256) async {
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
    } catch (e) {
      debugPrint('[DeltaUpdateService] Checksum verification failed: $e');
      return false;
    }
  }

  /// Applies the binary delta patch to reconstruct the new version in the staging directory
  Future<bool> applyPatchAndStage({
    required File patchFile,
    required String targetVersion,
  }) async {
    try {
      final stagedDir = await getStagingDirectory();
      
      // Clean staging directory
      if (await stagedDir.exists()) {
        for (final entity in stagedDir.listSync(recursive: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }

      final patcher = await getPatcherExecutable();
      if (patcher != null && await patcher.exists()) {
        debugPrint('[DeltaUpdateService] Running hpatchz: ${patcher.path} -f "${appDirectory.path}" "${patchFile.path}" "${stagedDir.path}"');
        
        final result = await Process.run(
          patcher.path,
          ['-f', appDirectory.path, patchFile.path, stagedDir.path],
        );

        if (result.exitCode == 0) {
          debugPrint('[DeltaUpdateService] Patch successfully applied into: ${stagedDir.path}');
          await _writePendingUpdateManifest(stagedDir, targetVersion);

          // Immediate cleanup of the temporary .patch file from system temp
          try {
            if (await patchFile.exists()) {
              await patchFile.delete();
              debugPrint('[DeltaUpdateService] Cleaned up temporary patch file');
            }
          } catch (_) {}

          return true;
        } else {
          debugPrint('[DeltaUpdateService] hpatchz failed with code ${result.exitCode}: ${result.stderr}');
        }
      }
    } catch (e) {
      debugPrint('[DeltaUpdateService] Failed to apply delta patch: $e');
    }
    return false;
  }

  /// Writes a marker manifest indicating a staged update is ready to be swapped
  Future<void> _writePendingUpdateManifest(Directory stagedDir, String targetVersion) async {
    final manifestFile = File(p.join(stagedDir.path, 'pending_update.json'));
    final data = {
      'target_version': targetVersion,
      'staged_at': DateTime.now().toIso8601String(),
      'source_executable': Platform.resolvedExecutable,
    };
    await manifestFile.writeAsString(jsonEncode(data));
  }

  /// Checks on startup if there was a pending staged update waiting to be applied
  Future<bool> hasPendingStagedUpdate() async {
    try {
      final stagedDir = await getStagingDirectory();
      final manifestFile = File(p.join(stagedDir.path, 'pending_update.json'));
      return await manifestFile.exists();
    } catch (_) {
      return false;
    }
  }

  /// Cleans up all staged update files from disk
  Future<void> clearStagingDirectory() async {
    try {
      final stagedDir = await getStagingDirectory();
      if (await stagedDir.exists()) {
        await stagedDir.delete(recursive: true);
        debugPrint('[DeltaUpdateService] Cleaned up staging directory');
      }
    } catch (e) {
      debugPrint('[DeltaUpdateService] Failed to clean staging directory: $e');
    }
  }

  /// Executes the instantaneous 1-second directory swap and app restart
  Future<void> executeInstantRestart() async {
    if (!Platform.isWindows) return;

    try {
      final stagedDir = await getStagingDirectory();
      final targetAppDir = appDirectory;
      final exeName = p.basename(Platform.resolvedExecutable);

      // Create detached swap batch script and invisible VBS wrapper in system temp
      final batFile = File(p.join(Directory.systemTemp.path, 'resonance_swap.bat'));
      final vbsFile = File(p.join(Directory.systemTemp.path, 'resonance_swap_launcher.vbs'));
      
      final batchContent = '''
@echo off
setlocal
timeout /t 1 /nobreak >nul

:: Robocopy moves all staged files into the target application directory
robocopy "${stagedDir.path}" "${targetAppDir.path}" /E /IS /IT /MOVE /R:5 /W:1 >nul

:: Clean up staging folder
if exist "${stagedDir.path}" rmdir /S /Q "${stagedDir.path}" >nul 2>&1

:: Relaunch Resonance cleanly
start "" "${p.join(targetAppDir.path, exeName)}"

:: Self-destruct temporary scripts
del "${vbsFile.path}" >nul 2>&1
del "%~f0" >nul 2>&1
exit
''';

      await batFile.writeAsString(batchContent);

      // VBScript runs the batch file with window style 0 (100% invisible, no CMD flash)
      final vbsContent = 'CreateObject("WScript.Shell").Run """${batFile.path}""", 0, False';
      await vbsFile.writeAsString(vbsContent);

      // Launch invisible wscript and terminate current process immediately
      try {
        await Process.start(
          'wscript.exe',
          [vbsFile.path],
          mode: ProcessStartMode.detached,
        );
      } catch (_) {
        await Process.start(
          'cmd.exe',
          ['/c', batFile.path],
          mode: ProcessStartMode.detached,
        );
      }

      exit(0);
    } catch (e) {
      debugPrint('[DeltaUpdateService] Failed to execute instant restart: $e');
    }
  }
}

final deltaUpdateServiceProvider = Provider<DeltaUpdateService>((ref) {
  return DeltaUpdateService();
});
