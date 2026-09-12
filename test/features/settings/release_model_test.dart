import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/settings/data/models/release_model.dart';

void main() {
  group('AppRelease Model & Multi-Delta Asset Matching Tests', () {
    test('compareSemVer handles various semver formats accurately', () {
      expect(AppRelease.compareSemVer('0.1.6-beta+7', '0.1.5-beta+6'), greaterThan(0));
      expect(AppRelease.compareSemVer('0.1.5-beta', '0.1.6-beta'), lessThan(0));
      expect(AppRelease.compareSemVer('0.1.5', '0.1.5-beta'), equals(0));
      expect(AppRelease.compareSemVer('v0.1.6', '0.1.5'), greaterThan(0));
      expect(AppRelease.compareSemVer('0.1.6-beta+7', '0.1.6-beta+7'), equals(0));
    });

    test('getDeltaPatchAsset picks the exact matching patch asset for 0.1.4 and 0.1.3 users', () {
      final releaseJson = {
        'tag_name': 'v0.1.6-beta',
        'name': 'Resonance v0.1.6-beta',
        'body': 'Release notes for 0.1.6-beta',
        'prerelease': true,
        'published_at': '2026-08-21T12:00:00Z',
        'assets': [
          {
            'name': 'Resonance-v0.1.5-beta-to-v0.1.6-beta-delta.patch',
            'browser_download_url': 'https://github.com/.../0.1.5-to-0.1.6.patch',
            'size': 2000000,
          },
          {
            'name': 'Resonance-v0.1.4-beta-to-v0.1.6-beta-delta.patch',
            'browser_download_url': 'https://github.com/.../0.1.4-to-0.1.6.patch',
            'size': 3000000,
          },
          {
            'name': 'Resonance-v0.1.3-beta-to-v0.1.6-beta-delta.patch',
            'browser_download_url': 'https://github.com/.../0.1.3-to-0.1.6.patch',
            'size': 3500000,
          },
          {
            'name': 'Resonance-v0.1.6-beta-Windows.exe',
            'browser_download_url': 'https://github.com/.../full_installer.exe',
            'size': 95000000,
          }
        ]
      };

      // User on 0.1.5-beta
      final releaseForV15 = AppRelease.fromJson(releaseJson, '0.1.5-beta');
      final patchV15 = releaseForV15.getDeltaPatchAsset('0.1.5-beta');
      expect(patchV15, isNotNull);
      expect(patchV15!['name'], equals('Resonance-v0.1.5-beta-to-v0.1.6-beta-delta.patch'));

      // User on 0.1.4-beta
      final releaseForV14 = AppRelease.fromJson(releaseJson, '0.1.4-beta');
      final patchV14 = releaseForV14.getDeltaPatchAsset('0.1.4-beta');
      expect(patchV14, isNotNull);
      expect(patchV14!['name'], equals('Resonance-v0.1.4-beta-to-v0.1.6-beta-delta.patch'));

      // User on 0.1.3-beta
      final releaseForV13 = AppRelease.fromJson(releaseJson, '0.1.3-beta');
      final patchV13 = releaseForV13.getDeltaPatchAsset('0.1.3-beta');
      expect(patchV13, isNotNull);
      expect(patchV13!['name'], equals('Resonance-v0.1.3-beta-to-v0.1.6-beta-delta.patch'));

      // User on 0.1.1 (no patch exists) -> returns null (triggers fallback to full installer)
      final releaseForV11 = AppRelease.fromJson(releaseJson, '0.1.1');
      final patchV11 = releaseForV11.getDeltaPatchAsset('0.1.1');
      expect(patchV11, isNull);

      // Downgrade / equal version -> returns null (never corrupts with backward patch)
      final releaseForV16 = AppRelease.fromJson(releaseJson, '0.1.6-beta');
      final patchV16 = releaseForV16.getDeltaPatchAsset('0.1.6-beta');
      expect(patchV16, isNull);
    });

    test('In-place hotfix patch detection: 0.1.6-beta+7 detects 0.1.6-beta+8 patch under same tag', () {
      final hotfixReleaseJson = {
        'tag_name': 'v0.1.6-beta', // Tag on GitHub stays the same
        'name': 'Resonance v0.1.6-beta',
        'body': 'Hotfix release notes',
        'prerelease': true,
        'published_at': '2026-08-21T14:00:00Z',
        'assets': [
          {
            'name': 'Resonance-v0.1.6-beta+7-to-v0.1.6-beta+8-delta.patch',
            'browser_download_url': 'https://github.com/.../0.1.6-beta+7-to-0.1.6-beta+8.patch',
            'size': 650000, // ~650 KB hotfix!
          },
          {
            'name': 'Resonance-v0.1.5-beta-to-v0.1.6-beta+8-delta.patch',
            'browser_download_url': 'https://github.com/.../0.1.5-to-0.1.6-beta+8.patch',
            'size': 2500000,
          },
          {
            'name': 'Resonance-v0.1.6-beta-Windows.exe',
            'browser_download_url': 'https://github.com/.../full_installer.exe',
            'size': 95000000,
          }
        ]
      };

      // User currently on 0.1.6-beta+7
      final releaseForUser7 = AppRelease.fromJson(hotfixReleaseJson, '0.1.6-beta+7');
      expect(releaseForUser7.isNewerThanCurrent, isTrue); // Detected newer Build 8!
      expect(releaseForUser7.isCurrentVersion, isFalse);

      final hotfixPatch = releaseForUser7.getDeltaPatchAsset('0.1.6-beta+7');
      expect(hotfixPatch, isNotNull);
      expect(hotfixPatch!['name'], equals('Resonance-v0.1.6-beta+7-to-v0.1.6-beta+8-delta.patch'));

      // User already on 0.1.6-beta+8
      final releaseForUser8 = AppRelease.fromJson(hotfixReleaseJson, '0.1.6-beta+8');
      expect(releaseForUser8.isNewerThanCurrent, isFalse);
      expect(releaseForUser8.isCurrentVersion, isTrue);
      expect(releaseForUser8.getDeltaPatchAsset('0.1.6-beta+8'), isNull);
    });

    test('Android APK build detection: extracts build from APK filename and detects updates', () {
      final androidReleaseJson = {
        'tag_name': 'v0.1.8-beta', // Tag stays 0.1.8-beta
        'name': 'Resonance v0.1.8-beta',
        'body': 'Android release notes',
        'prerelease': true,
        'published_at': '2026-09-12T12:00:00Z',
        'assets': [
          {
            'name': 'Resonance-v0.1.8-beta.12-Android.apk',
            'browser_download_url': 'https://github.com/.../Resonance-v0.1.8-beta.12-Android.apk',
            'size': 36500000,
          },
          {
            'name': 'Resonance-Setup-v0.1.8-beta.exe',
            'browser_download_url': 'https://github.com/.../full_installer.exe',
            'size': 75000000,
          }
        ]
      };

      // Android user on build 11 (0.1.8-beta+11) detects build 12 is available
      final releaseForUser11 = AppRelease.fromJson(androidReleaseJson, '0.1.8-beta+11');
      expect(releaseForUser11.isNewerThanCurrent, isTrue);
      expect(releaseForUser11.isCurrentVersion, isFalse);

      // Android user on build 12 (0.1.8-beta+12) detects already up to date
      final releaseForUser12 = AppRelease.fromJson(androidReleaseJson, '0.1.8-beta+12');
      expect(releaseForUser12.isNewerThanCurrent, isFalse);
      expect(releaseForUser12.isCurrentVersion, isTrue);

      // 4-number versioning support in compareSemVer
      expect(AppRelease.compareSemVer('0.1.8.12', '0.1.8.11'), greaterThan(0));
      expect(AppRelease.compareSemVer('0.1.8.12', '0.1.8.12'), equals(0));
      expect(AppRelease.compareSemVer('0.1.8.11', '0.1.8.12'), lessThan(0));
    });

    test('Proposal B Android APK naming: extracts build and matches ABI variants', () {
      final proposalBReleaseJson = {
        'tag_name': 'v0.1.8-beta',
        'name': 'Resonance v0.1.8-beta',
        'body': 'Release notes',
        'prerelease': false,
        'published_at': '2026-09-12T12:00:00Z',
        'assets': [
          {
            'name': 'Resonance-v0.1.8.12-Android-64bit-arm64.apk',
            'browser_download_url': 'https://github.com/.../arm64.apk',
            'size': 35500000,
          },
          {
            'name': 'Resonance-v0.1.8.12-Android-32bit-v7a.apk',
            'browser_download_url': 'https://github.com/.../v7a.apk',
            'size': 30200000,
          },
          {
            'name': 'Resonance-v0.1.8.12-Android-Universal.apk',
            'browser_download_url': 'https://github.com/.../universal.apk',
            'size': 96800000,
          },
        ]
      };

      final release = AppRelease.fromJson(proposalBReleaseJson, '0.1.8+11');
      expect(release.isNewerThanCurrent, isTrue);

      // 64-bit arm64 test
      final arm64Asset = release.getCompatibleInstallerAsset(isAndroidOverride: true, abiOverride: Abi.androidArm64);
      expect(arm64Asset, isNotNull);
      expect(arm64Asset!['name'], equals('Resonance-v0.1.8.12-Android-64bit-arm64.apk'));
      final arm64Desc = release.getCompatibleInstallerDescription(isAndroidOverride: true, abiOverride: Abi.androidArm64);
      expect(arm64Desc, contains('64-bit (arm64)'));

      // 32-bit v7a test
      final v7aAsset = release.getCompatibleInstallerAsset(isAndroidOverride: true, abiOverride: Abi.androidArm);
      expect(v7aAsset, isNotNull);
      expect(v7aAsset!['name'], equals('Resonance-v0.1.8.12-Android-32bit-v7a.apk'));
      final v7aDesc = release.getCompatibleInstallerDescription(isAndroidOverride: true, abiOverride: Abi.androidArm);
      expect(v7aDesc, contains('32-bit (v7a)'));
    });

    test('Android split-per-abi build number normalization & comparison', () {
      // 1. normalizeBuildNumber handles standard ABI prefixes
      expect(AppRelease.normalizeBuildNumber('2012'), equals('12')); // arm64-v8a (2000 + 12)
      expect(AppRelease.normalizeBuildNumber('1012'), equals('12')); // armeabi-v7a (1000 + 12)
      expect(AppRelease.normalizeBuildNumber('3012'), equals('12')); // x86_64 (3000 + 12)
      expect(AppRelease.normalizeBuildNumber('2013'), equals('13')); // arm64-v8a (2000 + 13)
      expect(AppRelease.normalizeBuildNumber('12'), equals('12'));   // Universal / Windows
      expect(AppRelease.normalizeBuildNumber('0'), equals('0'));

      // 2. compareSemVer correctly identifies Build 13 as newer than installed ARM64 Build 12 (2012)
      expect(AppRelease.compareSemVer('0.1.8-beta+13', '0.1.8-beta+2012'), greaterThan(0));
      expect(AppRelease.compareSemVer('0.1.8-beta+13', '0.1.8-beta+1012'), greaterThan(0));
      expect(AppRelease.compareSemVer('0.1.8-beta+13', '0.1.8-beta+2013'), equals(0));
      expect(AppRelease.compareSemVer('0.1.8-beta+12', '0.1.8-beta+2013'), lessThan(0));
      expect(AppRelease.compareSemVer('0.1.8.13', '0.1.8.2012'), greaterThan(0));

      // 3. Full AppRelease.fromJson test with user running 0.1.8-beta+2012
      final releaseJson = {
        'tag_name': 'v0.1.8-beta',
        'name': 'Resonance v0.1.8-beta',
        'body': 'What\'s New in v0.1.8-beta (Build 13)',
        'prerelease': true,
        'published_at': '2026-09-12T18:00:00Z',
        'assets': [
          {
            'name': 'Resonance-v0.1.8-beta.13-Android-64bit-arm64.apk',
            'browser_download_url': 'https://github.com/.../arm64.apk',
            'size': 34300000,
          },
        ]
      };

      final release = AppRelease.fromJson(releaseJson, '0.1.8-beta+2012');
      expect(release.isNewerThanCurrent, isTrue);
      expect(release.isOlderThanCurrent, isFalse);
      expect(release.isCurrentVersion, isFalse);
    });
  });
}
