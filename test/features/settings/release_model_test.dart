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
  });
}
