# Resonance - Android Build & Optimization Guide

This directory contains the Android platform project files for **Resonance** (Premium Hybrid Music Streaming App).

---

## 🚀 Recommended Android Build Commands

### 1. Split APKs (Best for Direct GitHub Releases & Sideloading)
Splits the APK by CPU architecture (`arm64-v8a`, `armeabi-v7a`, `x86_64`). Reduces individual APK download sizes from ~40MB+ down to **~15–18MB**:
```bash
flutter build apk --release --split-per-abi
```
*Output location:* `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

### 2. Android App Bundle (AAB - Best for Google Play Store)
Generates a dynamic Android App Bundle (`.aab`). Google Play optimizes installation packages per user device automatically:
```bash
flutter build appbundle --release
```
*Output location:* `build/app/outputs/bundle/release/app-release.aab`

---

### 3. Maximum Size Reduction & Obfuscation
Strips unused symbols and obfuscates Dart code for enhanced security and smaller binary footprints:
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
```

---

## ⚡ Size Optimization & Platform Isolation Details

1. **Automatic Desktop Plugin Stripping**:
   - Desktop-only native C++/FFI dependencies (e.g., `window_manager`, `screen_retriever`) are automatically ignored by Flutter's Android Gradle build toolchain (`flutter_tools`).
2. **Tree Shaking & Dead Code Elimination**:
   - Unused Dart libraries and icons are tree-shaken automatically during `flutter build --release`.
3. **R8 / ProGuard Shrinking**:
   - Android native code is minified and optimized via R8 during the release build task.

---

## 🔑 Release Signing Setup (Optional)

To sign release builds for distribution:
1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Configure `android/key.properties`:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
