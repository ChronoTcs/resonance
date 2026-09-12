# Resonance Release Packaging & Build Automation

This directory contains automated packaging scripts and workflows for building production releases of **Resonance** across Windows and Android platforms.

---

## 🤖 GitHub Actions CI/CD Release Pipeline

The primary production release engine runs via GitHub Actions defined in [`.github/workflows/release.yml`](file:///d:/File%20Mata%20Kuliah/Projek/streamly/resonance/.github/workflows/release.yml).

### Pipeline Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Trigger Event                                    │
│       • Push Tag: git push origin v* (e.g., v0.1.8-beta)                    │
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
   version: 0.1.8-beta+13   # Format: <major>.<minor>.<patch>[-<prerelease>]+<build_number>
   ```
2. **`python_engine/version_info.txt`**:
   ```python
   filevers=(0, 1, 8, 13),
   prodvers=(0, 1, 8, 13),
   # ...
   StringStruct(u'FileVersion', u'0.1.8.13'),
   StringStruct(u'ProductVersion', u'0.1.8-beta+13')
   ```
3. **`windows/resonance_installer.iss`** (when updating base version):
   ```iss
   #define MyAppVersion "0.1.8-beta"
   #define MyAppNumericVersion "0.1.8.0"
   ```

### Step 2: Prepare Release Notes & Commit Reports
Document what changed in the project reports folders:
- **Commit Summary**: Create `reports/commits/commit_v<version>_build<build>.md` (e.g. [`commit_v0.1.8_build13.md`](file:///d:/File%20Mata%20Kuliah/Projek/streamly/resonance/reports/commits/commit_v0.1.8_build13.md)).
- **Release Notes**: Update `reports/releases/release_v<version>_notes.md` and create `reports/releases/release_v<version>-beta_notes.md` (e.g. [`release_v0.1.8-beta_notes.md`](file:///d:/File%20Mata%20Kuliah/Projek/streamly/resonance/reports/releases/release_v0.1.8-beta_notes.md)).
- **State Memory**: Update `graphify-out/Resonance_State.md` with new features, bug fixes, and architectural notes.

### Step 3: Run Automated Verification
Verify that the codebase compiles and all tests pass with zero failures:
```powershell
flutter test
```

### Step 4: Commit & Push Code to Main Branch
```powershell
git add .
git commit -F "reports/commits/commit_v0.1.8_build13.md"
git push origin main
```

### Step 5: Trigger GitHub Actions Release

#### Option A: Trigger via Git Tag (Automatic)
- **New Release Tag:**
  ```powershell
  git tag -a v0.1.8-beta -m "Release v0.1.8-beta (Build 13)"
  git push origin v0.1.8-beta
  ```
- **Updating an Existing Release Tag with a New Build:**
  If the release tag `v0.1.8-beta` already exists on GitHub and you want to rebuild it with the new build number:
  ```powershell
  git tag -fa v0.1.8-beta -m "Update v0.1.8-beta to Build 13"
  git push origin v0.1.8-beta --force
  ```

#### Option B: Trigger via GitHub Actions UI (Manual Dispatch)
1. Navigate to the repository on GitHub.
2. Go to **Actions** → select **Release Pipeline**.
3. Click **Run workflow** dropdown on the right.
4. Select the `main` branch and enter the target tag (e.g. `v0.1.8-beta`).
5. Click **Run workflow**.

---

## 📦 Expected Release Assets & File Naming

The pipeline compiles and publishes the following binaries to the GitHub Release:

| File Name | Platform | Description |
| :--- | :--- | :--- |
| `Resonance-v0.1.8-beta.13-Android-64bit-arm64.apk` | Android | Optimized 64-bit ARM APK (~33 MB) |
| `Resonance-v0.1.8-beta.13-Android-32bit-v7a.apk` | Android | Optimized 32-bit ARM APK (~29 MB) |
| `Resonance-v0.1.8-beta.13-Android-Universal.apk` | Android | Universal APK for all CPU architectures (~92 MB) |
| `Resonance-Setup-v0.1.8-beta.exe` | Windows | Inno Setup Windows Full Installer (~97 MB) |
| `Resonance-v0.1.8-beta-Windows-Portable.zip` | Windows | Standalone portable zip archive (~124 MB) |
| `Resonance-...-to-v0.1.8-beta...delta.patch` | Windows | Differential binary patch via HDiffPatch (<26 MB) |

---

## 💻 Local Packaging Scripts (PowerShell)

For building release packages locally without GitHub Actions:

### 1. `package_windows.ps1`
Builds Flutter Windows release, compiles Inno Setup installer, packages portable ZIP, auto-detects previous release to generate binary delta patches (`.patch`), and produces `manifest.json`.
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_windows.ps1"
```

### 2. `package_android.ps1`
Builds Android Universal APK, Split-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`), and Google Play AppBundle (`.aab`) into `Releases/v<Version>/Android/`.
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_android.ps1"
```

### 3. `package_all.ps1`
Master runner script that executes both Windows and Android packaging sequentially.
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/package_all.ps1"
```

---

## ⚙️ Local Prerequisites & Tools

- **Flutter SDK:** In system `PATH`.
- **Inno Setup 6:** Installed at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` or `C:\Program Files\Inno Setup 6\ISCC.exe`.
- **HDiffPatch (`hdiffz.exe` / `hpatchz.exe`):** Located in `windows/tools/` for computing differential delta patches.
- **Python 3.10+:** With `pyinstaller`, `yt-dlp`, `requests`, `mutagen` for Windows downloader engine compilation.
