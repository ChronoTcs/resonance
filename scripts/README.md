# Resonance Release Packaging & Build Automation

This directory contains automated packaging scripts for building production releases of **Resonance** across Windows and Android platforms.

---

## 📁 Output Directory Structure

All generated release artifacts are saved in the project's root `Releases/` folder (`resonance/Releases/`), structured by version and platform:

```text
resonance/
├── Releases/                                  <-- Unified Root Releases Directory
│   ├── v0.1.2/
│   │   ├── Windows/
│   │   │   ├── Resonance-v0.1.2-Windows.exe            # Inno Setup Full Installer
│   │   │   ├── Resonance-v0.1.2-Windows-Portable.zip   # Portable ZIP Archive
│   │   │   ├── Release_v0.1.2/                         # Unpacked Release Directory
│   │   │   └── manifest.json                           # SHA-256 Checksums & Metadata
│   │   └── Android/
│   │       ├── Resonance-v0.1.2-Android-Universal.apk  # Universal APK (All Arch)
│   │       ├── Resonance-v0.1.2-Android-arm64-v8a.apk  # 64-bit ARM APK
│   │       ├── Resonance-v0.1.2-Android-armeabi-v7a.apk# 32-bit ARM APK
│   │       ├── Resonance-v0.1.2-Android.aab            # Google Play App Bundle
│   │       └── manifest.json
│   └── v0.1.3/
│       ├── Windows/
│       │   ├── Resonance-v0.1.3-Windows.exe
│       │   ├── Resonance-v0.1.3-Windows-Portable.zip
│       │   ├── Resonance-v0.1.2-to-v0.1.3-delta.patch   # ~2.5 MB Binary Delta Patch (HDiffPatch)
│       │   └── manifest.json
│       └── Android/ ...
```

---

## 🚀 Available Packaging Scripts

### 1. `package_windows.ps1`
Builds the Flutter Windows release, compiles the Inno Setup installer, packages the portable ZIP, auto-detects the previous release to generate binary delta patches (`.patch`), and produces `manifest.json`.

**Usage:**
```powershell
# Automatically reads version from pubspec.yaml:
powershell -ExecutionPolicy Bypass -File "scripts/package_windows.ps1"

# Or specify a custom version tag:
powershell -ExecutionPolicy Bypass -File "scripts/package_windows.ps1" -Version "0.1.3"
```

### 2. `package_android.ps1`
Builds Android Universal APK, Split-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`), and Google Play AppBundle (`.aab`), saving all outputs into `Releases/v<Version>/Android/`.

**Usage:**
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_android.ps1"
```

### 3. `package_all.ps1`
Master runner script that executes both Windows and Android packaging sequentially in one command.

**Usage:**
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_all.ps1"
```

---

## ⚙️ Prerequisites & Tools

- **Flutter SDK:** Available in system `PATH`.
- **Inno Setup 6:** (For Windows installer `.exe` generation) installed at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` or `C:\Program Files\Inno Setup 6\ISCC.exe`.
- **HDiffPatch (`hdiffz.exe` / `hpatchz.exe`):** Located in `windows/tools/` for computing and applying differential delta patches.
