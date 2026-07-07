# Resonance Music App

Resonance is a premium, high-performance hybrid music and video streaming application designed for Windows Desktop and Android Mobile platforms. It combines native offline audio management with seamless YouTube search, resolver, sniffer, and caching architectures.

---

## Key Features

### 🎵 1. Premium Audio & Video Playback
*   **Dual Mode Player:** Seamlessly handles local audio files (MP3, FLAC, M4A, etc.) and online YouTube streams.
*   **Aesthetic UI/UX:** Features dynamic artwork-based blur backgrounds, smooth transitions, standardized Flaticon UIcons, and custom responsive layouts.
*   **Floating overlay / PiP:** Standardized floating player bubble and Picture-in-Picture capability on Windows and Android.

### 🌐 2. SOTA YouTube Stream Resolving
*   **Windows Subprocess Bridge:** Outsources heavy YouTube URL deciphering and downloading tasks to a lightweight Python IPC daemon (`resonance_downloader.py` running `yt-dlp`).
*   **Android MethodChannel:** Decrypts signature cipher keys natively using a MethodChannel calling `com.zemer.cipher.CipherDeobfuscator` in Java/Kotlin.
*   **Fast Cache-Bypass:** Eliminates network prefetch delays by automatically bypassing the cache layer during active downloads.

### 🎛️ 3. Equalizer & Audio Settings
*   **9-Band Hardware Equalizer:** Custom frequency sliders with link-control settings to raise/lower adjacent bands smoothly.
*   **Presets:** Built-in profiles ("Flat", "Bass Boost", "Vocal") and "Custom" memory slots.
*   **Playback Speed & Pitch:** Dynamic real-time speed modifiers.

### 💾 4. Cache & Database Management
*   **SQLite Storage:** Offline-first caching of track metadata, local directories, search history, and lyrics translations.
*   **Granular Cache Controls:** Settings module allowing users to selectively clear image cache, lyrics, or purge all storage.

---

## Architecture Overview (Clean + Feature-First)

The project follows a **Feature-First + Clean Architecture** structure to ensure high testability, maintainability, and clear separation of concerns:

```text
lib/
├── core/                  # Global utilities, global widgets, themes
│   ├── utils/             # AppIcons constant map, theme systems
│   └── widgets/           # AppBackButton, CollapseButton, PlayPauseButton
└── features/              # Feature scopes
    ├── player/            # Fullscreen and docked controllers, audio state
    ├── download/          # Download queue, Python bridge bridge/datasource
    ├── library/           # Local catalog parser, directory scanner
    └── lyrics/            # Lyrics syncer, translation API wrappers
```

Each feature folder is divided into three layers:
1.  `presentation/`: UI screens, components, and UI Notifier controllers.
2.  `application/`: High-level business logic, orchestrators, and providers (Riverpod).
3.  `data/`: Repositories, API datasources, and local models.

---

## Development & Building

### Prerequisites
*   Flutter SDK `^3.11.1`
*   Python `3.10+` (Windows only for bridge development)
*   FFmpeg (Placed inside `python_engine/bin/`)

### Production Build Commands

#### 🤖 Android Build (Optimized Size)
To avoid bundling native `libmpv` libraries for unused CPU architectures (saving ~70MB of APK bloat):
```bash
flutter build apk --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
```

#### 🪟 Windows Build
```bash
flutter build windows --release
```
*Note: Make sure to copy the Python `resonance_downloader.exe` and FFmpeg binaries (`bin/` directory containing `ffmpeg.exe` and `ffprobe.exe`) directly adjacent to the compiled `resonance_app.exe` in the release output folder.*
