Fix: Normalize Android split-per-abi build numbers, resolve downgrade warning false-positives, and decouple automatic updates toggle from install permission

• Android Split-per-ABI Build Normalization: implement AppRelease.normalizeBuildNumber to modulo 1000 ABI split offsets (e.g. 2012 -> 12, 2013 -> 13, 1012 -> 12) added by Flutter Gradle plugin, fixing +2012 display on Android ARM64
• SemVer Comparison Fix: update compareSemVer and AppRelease.fromJson to normalize ABI split offsets in both semver build suffixes (+N) and 4-number version strings, fixing false "Older than installed version" downgrade warnings
• Automatic Updates Permission Decoupling: decouple Automatic Updates switch from premature REQUEST_INSTALL_PACKAGES check; request install permission contextually when user initiates APK installation in installRelease
• Multiplatform Subtitle Polish: update Android auto-update subtitle to clarify that install permission is requested when update is ready
• Unit & Widget Test Suite: add tests in release_model_test.dart and release_manager_screen_test.dart covering ABI normalization and switch toggling
