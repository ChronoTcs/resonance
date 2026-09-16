# Resonance Release Packaging & Build Automation

This directory contains automated packaging scripts and workflows for building production releases of **Resonance** across Windows and Android platforms.

---

## 🤖 GitHub Actions CI/CD Release Pipeline

The primary production release engine runs via GitHub Actions defined in [`.github/workflows/release.yml`](file:///d:/File%20Mata%20Kuliah/Projek/streamly/resonance/.github/workflows/release.yml).

### Pipeline Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Trigger Event                                    │
│       • Push Tag: git push origin v* (e.g., v0.1.9-beta)                    │
│       • Manual Workflow Dispatch: Actions > Release Pipeline > Run          │
└───────────────────────┬─────────────────────────────────────┬───────────────┘
                        │                                     │
                        ▼                                     ▼
        ┌───────────────────────────────┐     ┌───────────────────────────────┐
        │   Job 1: build-android        │     │   Job 2: build-windows        │
        │   Runner: ubuntu-latest       │     │   Runner: windows-latest      │
        ├───────────────────────────────┤     ├───────────────────────────────┤
        │ • Setup Java 17 & Flutter     │     │ • Setup Python 3.11 & deps    │
        │ • Extract Version & Build Num │     │ • Bundle real FFmpeg (>10MB)  │
        │ • Sign Keystore (if present)  │     │ • PyInstaller build engine    │
        │ • Build Split-ABI APKs:       │     │ • Build Flutter Windows app   │
        │   - 64bit-arm64 (~33 MB)      │     │ • Package Portable .zip       │
        │   - 32bit-v7a (~29 MB)        │     │ • Generate Delta Patch        │
        │ • Build Universal APK (~92 MB)│     │   (via hdiffz vs prev release)│
        │ • Upload android-binaries     │     │ • Inno Setup Installer (.exe) │
        │                               │     │ • Upload windows-binaries     │
        └───────────────┬───────────────┘     └───────────────┬───────────────┘
                        │                                     │
                        └─────────────────┬───────────────────┘
                                          ▼
                        ┌───────────────────────────────────┐
                        │   Job 3: publish-release          │
                        │   Runner: ubuntu-latest           │
                        ├───────────────────────────────────┤
                        │ • Download Android & Windows bins │
                        │ • Resolve tag & release notes     │
                        │   from reports/releases/          │
                        │ • Publish / Update GitHub Release │
                        │   via softprops/action-gh-release │
                        └───────────────────────────────────┘
```

---

## 📋 Standard Operating Procedure (SOP): Updates, Commits, Builds & Tags

Follow this checklist whenever releasing an update, pushing new commits, or triggering a new build:

### Step 1: Increment Version & Build Number
Always keep the version and build numbers in sync across configuration files:
1. **`pubspec.yaml`**:
   ```yaml
   version: 0.1.9-beta+14   # Format: <major>.<minor>.<patch>[-<prerelease>]+<build_number>
   ```
2. **`python_engine/version_info.txt`**:
   ```python
   filevers=(0, 1, 9, 14),
   prodvers=(0, 1, 9, 14),
   # ...
   StringStruct(u'FileVersion', u'0.1.9.14'),
   StringStruct(u'ProductVersion', u'0.1.9-beta+14')
   ```
3. **`windows/resonance_installer.iss`** (when updating base version):
   ```iss
   #define MyAppVersion "0.1.9-beta"
   #define MyAppNumericVersion "0.1.9.0"
   ```

### Step 2: Prepare Release Notes & Commit Reports
Document what changed in the project reports folders:
- **Commit Summary**: Create `reports/commits/commit_v<version>_build<build>.md` (e.g. `reports/commits/commit_v0.1.9_build14.md`).
- **Release Notes**: Update `reports/releases/release_v<version>_notes.md` and create `reports/releases/release_v<version>-beta_notes.md` (e.g. `reports/releases/release_v0.1.9-beta_notes.md`).
- **State Memory**: Update `graphify-out/Resonance_State.md` with new features, bug fixes, and architectural notes.

### Step 3: Run Automated Verification
Verify that the codebase compiles and all tests pass with zero failures:
```powershell
flutter test
```

### Step 4: Commit & Push Code to Main Branch
```powershell
git add .
git commit -F "reports/commits/commit_v0.1.9_build14.md"
git push origin main
```

### Step 5: Trigger GitHub Actions Release

#### Option A: Trigger via Git Tag (Automatic)
- **New Release Tag:**
  ```powershell
  git tag -a v0.1.9-beta -m "Release v0.1.9-beta (Build 14)"
  git push origin v0.1.9-beta
  ```
- **Updating an Existing Release Tag with a New Build:**
  If the release tag `v0.1.9-beta` already exists on GitHub and you want to rebuild it with the new build number:
  ```powershell
  git tag -fa v0.1.9-beta -m "Update v0.1.9-beta to Build 14"
  git push origin v0.1.9-beta --force
  ```

#### Option B: Trigger via GitHub Actions UI (Manual Dispatch)
1. Navigate to the repository on GitHub.
2. Go to **Actions** → select **Release Pipeline**.
3. Click **Run workflow** dropdown on the right.
4. Select the `main` branch and enter the target tag (e.g. `v0.1.9-beta`).
5. Click **Run workflow**.

---

## 📦 Expected Release Assets & File Naming

The pipeline and local packaging scripts produce matching binaries conforming to Proposal B naming:

| File Name | Platform | Description |
| :--- | :--- | :--- |
| `Resonance-v0.1.9-beta.14-Android-64bit-arm64.apk` | Android | Optimized 64-bit ARM APK (~33 MB) |
| `Resonance-v0.1.9-beta.14-Android-32bit-v7a.apk` | Android | Optimized 32-bit ARM APK (~29 MB) |
| `Resonance-v0.1.9-beta.14-Android-Universal.apk` | Android | Universal APK for all CPU architectures (~92 MB) |
| `Resonance-v0.1.9-beta-Windows.exe` | Windows | Inno Setup Windows Full Installer (~97 MB) |
| `Resonance-v0.1.9-beta-Windows-Portable.zip` | Windows | Standalone portable zip archive (~124 MB) |
| `Resonance-...-to-v0.1.9-beta.14-delta.patch` | Windows | Differential binary patch via HDiffPatch (<26 MB) |

---

## 💻 Local Packaging Scripts (PowerShell)

All local packaging scripts are synchronized with GitHub Actions to output identical directory hierarchies, naming conventions, and manifests under `Releases/v<BaseVersion>/`:

### 1. `package_all.ps1` (Master Packager)
Master runner script that executes Windows, Android, or all platform packaging sequentially.
```powershell
# Package all platforms (Windows + Android)
powershell -ExecutionPolicy Bypass -File "scripts/package_all.ps1"

# Package Windows only (fast portable build without installer or python rebuild)
powershell -ExecutionPolicy Bypass -File "scripts/package_all.ps1" -Platform Windows -SkipPythonEngine -SkipInstaller

# Package Android only
powershell -ExecutionPolicy Bypass -File "scripts/package_all.ps1" -Platform Android
```

**Parameters**:
- `-Platform`: `All` (default), `Windows`, or `Android`.
- `-Version`: Target version string (defaults to `pubspec.yaml`).
- `-PreviousVersion`: Specify baseline for Windows delta patch generation.
- `-SkipPythonEngine`: Skip compiling `python_engine/build_downloader.py`.
- `-SkipInstaller`: Skip compiling Inno Setup `.exe` installer.
- `-BuildAppBundle`: Also compile Android `.aab` for Play Store.

### 2. `package_windows.ps1`
Builds Python Downloader Engine (`resonance_downloader.exe`), Flutter Windows release, Inno Setup installer, packages portable ZIP, auto-detects previous releases to generate delta patches (`.patch`), and produces `manifest.json`.
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_windows.ps1"
```

### 3. `package_android.ps1`
Builds Proposal B Split-ABI APKs (`64bit-arm64`, `32bit-v7a`, `x86_64`) and Universal APK into `Releases/v<BaseVersion>/Android/` alongside `manifest.json`.
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_android.ps1"
```

---

## 📱 Local Device Testing Instructions

To test a release build on your own devices before publishing:
- **Android Phone**:
  ```powershell
  adb install -r "Releases\v0.1.9-beta\Android\Resonance-v0.1.9-beta.14-Android-64bit-arm64.apk"
  ```
- **Windows PC**:
  - Run `Releases\v0.1.9-beta\Windows\Resonance-v0.1.9-beta-Windows.exe` to test full installer installation and registry registration.
  - Or extract `Releases\v0.1.9-beta\Windows\Resonance-v0.1.9-beta-Windows-Portable.zip` into any test directory to test standalone portable execution without overwriting your current app data.

---

## ⚙️ Local Prerequisites & Tools

- **Flutter SDK:** In system `PATH`.
- **Inno Setup 6:** Installed at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` or `C:\Program Files\Inno Setup 6\ISCC.exe`.
- **HDiffPatch (`hdiffz.exe` / `hpatchz.exe`):** Located in `windows/tools/` for computing differential delta patches.
- **Python 3.10+:** With `pyinstaller`, `yt-dlp`, `requests`, `mutagen` for Windows downloader engine compilation.
