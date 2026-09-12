import 'dart:ffi';
import 'dart:io';

class AppRelease {
  final String tagName;
  final String name;
  final String body;
  final bool isPrerelease;
  final DateTime publishedAt;
  final List<dynamic> assets;
  final bool isCurrentVersion;
  final bool isNewerThanCurrent;
  final bool isOlderThanCurrent;

  AppRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.isPrerelease,
    required this.publishedAt,
    required this.assets,
    this.isCurrentVersion = false,
    this.isNewerThanCurrent = false,
    this.isOlderThanCurrent = false,
  });

  bool get isBeta {
    final lowerTag = tagName.toLowerCase();
    final lowerName = name.toLowerCase();
    return isPrerelease ||
        lowerTag.contains('beta') ||
        lowerTag.contains('rc') ||
        lowerTag.contains('alpha') ||
        lowerName.contains('beta') ||
        lowerName.contains('pre-release');
  }

  /// Returns the optimal installer asset for the current OS and CPU architecture.
  /// On Android: Matches exact device ABI (arm64, v7a, x86_64) -> universal -> any .apk.
  /// On Windows: Matches .exe installer.
  Map<String, dynamic>? getCompatibleInstallerAsset({bool? isAndroidOverride, Abi? abiOverride}) {
    final isAndroid = isAndroidOverride ?? Platform.isAndroid;
    final isWindows = isAndroidOverride == true ? false : (isAndroidOverride == false ? true : Platform.isWindows);

    if (isAndroid) {
      String targetAbi = 'arm64';
      try {
        final currentAbi = abiOverride ?? Abi.current();
        switch (currentAbi) {
          case Abi.androidArm64:
            targetAbi = 'arm64';
            break;
          case Abi.androidArm:
            targetAbi = 'v7a';
            break;
          case Abi.androidX64:
            targetAbi = 'x86_64';
            break;
          case Abi.androidIA32:
            targetAbi = 'x86';
            break;
          default:
            targetAbi = 'arm64';
        }
      } catch (_) {
        targetAbi = 'arm64';
      }

      Map<String, dynamic>? targetMatch;
      Map<String, dynamic>? universalMatch;
      Map<String, dynamic>? anyApkMatch;

      for (var asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = asset['name'].toString().toLowerCase();
        if (name.endsWith('.apk')) {
          final isArm64 = (targetAbi == 'arm64' && (name.contains('arm64') || name.contains('64bit')));
          final isV7a = (targetAbi == 'v7a' && (name.contains('v7a') || name.contains('32bit') || name.contains('armeabi')));
          if (isArm64 || isV7a || name.contains(targetAbi)) {
            targetMatch = asset;
            break;
          } else if (name.contains('universal')) {
            universalMatch ??= asset;
          } else {
            anyApkMatch ??= asset;
          }
        }
      }
      return targetMatch ?? universalMatch ?? anyApkMatch;
    } else if (isWindows) {
      for (var asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = asset['name'].toString().toLowerCase();
        if (name.endsWith('.exe')) {
          return asset;
        }
      }
    }
    return null;
  }

  /// Human-friendly description of the detected installer asset (e.g. "APK: arm64-v8a (45 MB)")
  String? getCompatibleInstallerDescription({bool? isAndroidOverride, Abi? abiOverride}) {
    final asset = getCompatibleInstallerAsset(isAndroidOverride: isAndroidOverride, abiOverride: abiOverride);
    if (asset == null) return null;

    final name = asset['name'].toString();
    final sizeBytes = asset['size'] as num? ?? 0;
    final sizeMb = sizeBytes > 0 ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB' : '';

    final isAndroid = isAndroidOverride ?? Platform.isAndroid;
    final isWindows = isAndroidOverride == true ? false : (isAndroidOverride == false ? true : Platform.isWindows);

    if (isAndroid) {
      String variant = 'Universal';
      final lower = name.toLowerCase();
      if (lower.contains('arm64') || lower.contains('64bit')) {
        variant = '64-bit (arm64)';
      } else if (lower.contains('v7a') || lower.contains('32bit') || lower.contains('arm-')) {
        variant = '32-bit (v7a)';
      } else if (lower.contains('x86_64')) {
        variant = 'x86_64';
      } else if (lower.contains('universal')) {
        variant = 'Universal';
      }
      return sizeMb.isNotEmpty ? 'APK: $variant ($sizeMb)' : 'APK: $variant';
    } else if (isWindows) {
      return sizeMb.isNotEmpty ? 'Installer ($sizeMb)' : 'Installer';
    }
    return null;
  }

  /// Finds matching delta patch asset specifically created from the currently installed version
  Map<String, dynamic>? getDeltaPatchAsset(String currentVersion) {
    // 1. NEVER use delta patching for downgrades or identical versions (prevents binary corruption)
    if (!isNewerThanCurrent) return null;

    final cleanCurrent = currentVersion.replaceAll(RegExp(r'^[vV]'), '').toLowerCase();
    // Normalize + → . for matching against GitHub-safe filenames (e.g. "0.1.6-beta+8" → "0.1.6-beta.8")
    final normalizedCurrent = cleanCurrent.replaceAll('+', '.');
    final baseCurrent = cleanCurrent.split('-')[0].split('+')[0];

    for (var asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final rawName = asset['name'].toString().toLowerCase();
      // Normalize asset name: decode %2b back to . and replace any + with . for consistent matching
      final name = rawName.replaceAll('%2b', '.').replaceAll('+', '.');
      if (name.endsWith('.patch') && name.contains('-to-')) {
        // 2. Strict matching: patch must be specifically built for the user's current version
        final fromPart = name.split('-to-').first;
        if (fromPart.contains(normalizedCurrent) ||
            fromPart.contains('v$normalizedCurrent') ||
            fromPart.contains('-$normalizedCurrent-') ||
            fromPart.endsWith('-$normalizedCurrent') ||
            fromPart.contains('-$baseCurrent-') ||
            fromPart.endsWith('-$baseCurrent') ||
            fromPart.endsWith('-v$baseCurrent') ||
            fromPart.contains('-v$baseCurrent-')) {
          return asset;
        }
      }
    }
    return null;
  }

  /// Compares two version strings (e.g. '0.1.2-beta+3' vs '0.1.1-beta').
  /// Returns > 0 if v1 is newer than v2, < 0 if v1 is older than v2, and 0 if equal.
  static int compareSemVer(String v1, String v2) {
    List<int> parseNumeric(String v) {
      final sanitized = v.replaceAll(RegExp(r'^[vV]'), '').split('-')[0].split('+')[0];
      final parts = sanitized.split('.');
      return parts.map((p) => int.tryParse(p) ?? 0).toList();
    }

    final nums1 = parseNumeric(v1);
    final nums2 = parseNumeric(v2);

    final maxLen = nums1.length > nums2.length ? nums1.length : nums2.length;
    for (int i = 0; i < maxLen; i++) {
      final n1 = i < nums1.length ? nums1[i] : 0;
      final n2 = i < nums2.length ? nums2[i] : 0;
      if (n1 != n2) {
        return n1.compareTo(n2);
      }
    }

    // If base numeric parts (0.1.2 == 0.1.2) match, compare build numbers only when
    // BOTH versions have an explicit '+N' suffix.
    // Rationale: a GitHub release tag like 'v0.1.7-beta' (no build number) is the
    // canonical release for that version — hotfix build numbers (+10, +11…) are
    // internal and should never make the base tag appear "older than installed".
    final bool v1HasBuild = v1.contains('+');
    final bool v2HasBuild = v2.contains('+');

    if (!v1HasBuild || !v2HasBuild) {
      // One side has no explicit build number → treat as same release
      return 0;
    }

    int extractBuild(String v) {
      final buildStr = v.split('+').last;
      return int.tryParse(buildStr) ?? 0;
    }

    final b1 = extractBuild(v1);
    final b2 = extractBuild(v2);
    if (b1 != b2) {
      return b1.compareTo(b2);
    }

    return 0;
  }

  factory AppRelease.fromJson(Map<String, dynamic> json, String currentAppVersion) {
    final rawTag = json['tag_name'].toString();
    final assets = json['assets'] as List<dynamic>? ?? [];

    // Extract target build number from patch asset names if present (e.g. "...-to-v0.1.6-beta+8-delta.patch")
    String effectiveVersion = rawTag;
    int highestBuild = 0;
    for (var asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final assetName = asset['name'].toString().toLowerCase();
      if (assetName.endsWith('.patch') && assetName.contains('-to-')) {
        // Normalize %2b and + to . before parsing (GitHub-safe filenames use . as build separator)
        final normalized = assetName.replaceAll('%2b', '.').replaceAll('+', '.');
        final toPart = normalized.split('-to-').last
            .replaceAll('-delta.patch', '')
            .replaceAll('.patch', '');
        // toPart is like "v0.1.7-beta.1" — extract trailing build number after last dot
        final dotBuildMatch = RegExp(r'\.([0-9]+)$').firstMatch(toPart);
        if (dotBuildMatch != null) {
          final b = int.tryParse(dotBuildMatch.group(1)!) ?? 0;
          if (b > highestBuild) {
            highestBuild = b;
            final base = rawTag.split('+')[0];
            effectiveVersion = '$base+$highestBuild';
          }
        } else if (toPart.contains('+')) {
          // Legacy: handle old + style just in case
          final buildStr = toPart.split('+').last;
          final b = int.tryParse(buildStr) ?? 0;
          if (b > highestBuild) {
            highestBuild = b;
            final base = rawTag.split('+')[0];
            effectiveVersion = '$base+$highestBuild';
          }
        }
      } else if (assetName.endsWith('.apk')) {
        // Extract build number from Android APK (e.g. Resonance-v0.1.8-beta.12-Android-64bit-arm64.apk, Resonance-v0.1.8.12-Android.apk)
        final normalized = assetName.replaceAll('%2b', '.').replaceAll('+', '.');
        final apkBuildMatch = RegExp(r'v?\d+\.\d+\.\d+(?:-[a-zA-Z0-9]+)?[\.+](\d+)').firstMatch(normalized);
        if (apkBuildMatch != null) {
          final b = int.tryParse(apkBuildMatch.group(1)!) ?? 0;
          if (b > highestBuild) {
            highestBuild = b;
            final base = rawTag.split('+')[0];
            effectiveVersion = '$base+$highestBuild';
          }
        }
      } else if (assetName.endsWith('.exe')) {
        // Extract build number from standalone Windows installer (e.g. Resonance-Setup-v0.1.8-beta.12.exe, Resonance-Setup-v0.1.8.12.exe)
        final normalized = assetName.replaceAll('%2b', '.').replaceAll('+', '.');
        final exeBuildMatch = RegExp(r'v?\d+\.\d+\.\d+(?:-[a-zA-Z0-9]+)?[\.+](\d+)').firstMatch(normalized);
        if (exeBuildMatch != null) {
          final b = int.tryParse(exeBuildMatch.group(1)!) ?? 0;
          if (b > highestBuild) {
            highestBuild = b;
            final base = rawTag.split('+')[0];
            effectiveVersion = '$base+$highestBuild';
          }
        }
      }
    }

    final cmp = compareSemVer(effectiveVersion, currentAppVersion);
    final isCurrent = cmp == 0;
    final isNewer = cmp > 0;
    final isOlder = cmp < 0;

    return AppRelease(
      tagName: rawTag,
      name: (json['name'] != null && json['name'].toString().isNotEmpty)
          ? json['name'].toString()
          : rawTag,
      body: json['body']?.toString() ?? 'No release notes provided for this version.',
      isPrerelease: json['prerelease'] == true,
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '') ?? DateTime.now(),
      assets: assets,
      isCurrentVersion: isCurrent,
      isNewerThanCurrent: isNewer,
      isOlderThanCurrent: isOlder,
    );
  }

  AppRelease copyWith({
    bool? isCurrentVersion,
    bool? isNewerThanCurrent,
    bool? isOlderThanCurrent,
  }) {
    return AppRelease(
      tagName: tagName,
      name: name,
      body: body,
      isPrerelease: isPrerelease,
      publishedAt: publishedAt,
      assets: assets,
      isCurrentVersion: isCurrentVersion ?? this.isCurrentVersion,
      isNewerThanCurrent: isNewerThanCurrent ?? this.isNewerThanCurrent,
      isOlderThanCurrent: isOlderThanCurrent ?? this.isOlderThanCurrent,
    );
  }
}
