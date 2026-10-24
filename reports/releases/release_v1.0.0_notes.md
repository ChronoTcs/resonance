> [!WARNING]
> ### ⚠️ Critical Notice for Users Updating from Versions Below v0.1.9-beta
> If you are currently using a version **below v0.1.9-beta** on Android, you **must completely uninstall the older version** before installing this release, and download the standalone installer/APK directly from the release links below.
>
> **Why?**
> Versions prior to `v0.1.9-beta` lacked the unified Android Application ID and keystore signing identity required by Android's `PackageInstaller` subsystem. As a result, older builds cannot verify and install in-app updates over the air. Starting with `v0.1.9-beta` onward (including this `v1.0.0` release), the application uses a unified package identity and signing certificate, allowing all future updates to install seamlessly directly inside the app.

---

### What's New in v1.0.0 (Build 15) — Official Stable Release

- **🎉 Official Graduation to Stable v1.0.0**:
  - **Graduated from Beta to Stable**: Resonance has officially graduated from its beta phase into `v1.0.0` (Build 15). All production versioning is synchronized across `pubspec.yaml`, Windows Inno Setup installer (`1.0.0.0`), and Python engine metadata (`1.0.0.15`).
  - **Release Classifier Verification**: The in-app update checker and semantic version comparator now classify `v1.0.0` as `STABLE` (green production badge) and correctly identify newer stable releases over previous beta pre-releases.

- **⏱️ Recommendation-Safe Sleep Timer Architecture**:
  - **Zero Queue Truncation**: Unlike conventional music apps that truncate or discard upcoming queues when a sleep timer fires, Resonance's new sleep timer preserves 100% of your queue context, playlists, and upcoming recommendations. Playback pauses cleanly on schedule without destroying your listening session.
  - **End-of-Track Mode**: Added a dedicated "End of Track" sleep mode that allows the currently playing song to finish playing in its entirety before pausing.
  - **Dual-Unit Custom Duration (Hours & Minutes)**: Upgraded custom duration picker from single-unit minutes to a full `hours:minutes` stepper with increment/decrement steppers, quick shortcut chips (`+15m`, `+30m`, `+1h`, `Reset`), and bounded ranges (1m to 24h).
  - **Direct Keyboard Tap-to-Type**: Converted duration digit displays into tap-to-edit input fields with `digitsOnly` filtering, 2-digit limits, auto-selection on focus, and automatic 2-digit zero-padding (`05`, `30`).
  - **Smooth Volume Fadeout**: Features a gentle 10-second logarithmic volume ramp-down to 0% before pausing, automatically restoring your pre-fade volume level upon manual pause or cancellation.
  - **Explicit Activation State & Persistence**: Integrated master toggle switches and explicit Activate / Deactivate buttons. All chosen presets, custom durations, and fade preferences persist automatically across app restarts via `SharedPreferences`.

- **🧩 Modular Preferences Architecture & Zero-GPU Countdown**:
  - **Monolithic God-Code Elimination**: Refactored the 956-line monolithic `preferences_section.dart` into single-responsibility, clean architectural components under `lib/features/settings/presentation/widgets/preferences/`:
    - `CustomSleepTimerSheet`: Standalone floating modal bottom sheet for timer configuration.
    - `SleepTimerCountdownText`: Isolated leaf `ConsumerWidget` wrapped in a `RepaintBoundary` that consumes only `remainingDuration`. Ticking every second now incurs **zero rebuild overhead** on parent cards, settings screens, or the GPU rasterizer.
    - `SleepTimerCard`: Decoupled card using granular Riverpod selectors (`s.isEnabled`, `s.selectedMode`, `s.durationMinutes`) to prevent rebuilds on 1 Hz ticks.
    - `AppBehaviorCard`: Dedicated card for startup on boot, minimize-to-tray, and deep queue prefetch toggles.
    - `PreferencesUpdatesCard`: Dedicated card for automatic background update checking and release notes history.
  - **Mobile Soft Keyboard Adaptability**: Wrapped the custom sleep timer in `FloatingSheetShell` with `isScrollable: true` and tap-to-dismiss whitespace gestures. The sheet automatically accommodates Android virtual soft keyboards (`viewInsets.bottom`) without `RenderFlex` overflow errors.

- **⚡ Complete 100% GPU Blur Elimination & Repaint Isolation**:
  - **Zero-Cost Linear Gradients**: Eradicated 100% of expensive Skia `BackdropFilter` and `ImageFilter.blur` shaders across every screen and widget in the codebase (docked player, Now Playing screen, fullscreen audio view, lyrics view, queue screen, volume dialog, mobile hero cards, and floating sheets). Replaced them with mathematically zero-GPU static `LinearGradient` surfaces.
  - **144Hz Marquee Repaint Boundaries**: Wrapped `ResonanceMarqueeText` scrolling viewports inside dedicated `RepaintBoundary` widgets. High-refresh-rate 144Hz horizontal text tickers now animate smoothly without triggering paint invalidation across surrounding cards, scaffolds, or the bottom navigation bar.
  - **Seek Bar Repaint Isolation**: Isolated all high-frequency audio progress bars and seek sliders inside dedicated `RepaintBoundary` widgets, isolating 60Hz/120Hz playback progress ticks to the slider thumb alone.
  - **Disabled Video Pipeline for Audio**: Enforced `vo: 'null'` and `vid: 'no'` in native `media_kit` MPV configurations, completely disabling unused video output threads, video decoding contexts, and DirectX/OpenGL texture bindings.

- **🖥️ Native Win32 C++ System Tray & Desktop Resiliency**:
  - **Pure Win32 C++ System Tray**: Replaced third-party system tray plugins with a custom, high-performance native Win32 C++ tray implementation (`windows/runner/system_tray_manager.cpp`) using `Shell_NotifyIconW` and `TrackPopupMenuEx`.
  - **Explorer Restart Auto-Recovery**: Registered the `TaskbarCreated` window message to automatically restore the tray icon if Windows Explorer restarts or crashes.
  - **Resource Icon Loading**: Loads the application icon directly from the Windows PE executable resource (`IDI_APP_ICON`), completely eliminating fragile filesystem path heuristics and missing icon bugs.
  - **Unicode UTF-8 & Clickable Media Controls**: Enforced MSVC `/utf-8` compile flags to eliminate Unicode mojibake (`â–¶` -> `▶`). Selecting the tray menu's `🎵 [Track Title]` item automatically restores the main window and opens the Now Playing screen.
  - **Adaptive Win32 Dark Mode**: Dynamically synchronizes native Windows popup context menus with active application theme via `uxtheme.dll` (`SetPreferredAppMode`, `FlushMenuThemes`, and `DWMWA_USE_IMMERSIVE_DARK_MODE`).
  - **Window Minimization Render Throttling**: Integrated `isWindowRenderActiveProvider` to detect when the desktop window is minimized or occluded, suspending lyric synchronization and UI tickers to reduce idle CPU/GPU usage to near 0%.

- **📱 Android Edge-to-Edge System UI Integration**:
  - **True Edge-to-Edge Experience**: Enabled `SystemUiMode.edgeToEdge` with transparent system status and navigation bars.
  - **Contrast Enforcement Disablement**: Disabled Android 10+ artificial scrims (`enforceNavigationBarContrast` and `enforceStatusBarContrast`) across `MainActivity.kt`, `styles.xml`, and `values-night/styles.xml`.
  - **Dynamic Theme Brightness Sync**: Wrapped the root application in an `AnnotatedRegion<SystemUiOverlayStyle>` that synchronizes icon and status bar brightness with dynamic theme changes.

- **🔁 Seamless Repeat-One Audio Loop & Prefetch Subsystem Guarding**:
  - **Zero-Stutter Audio Track Looping**: When repeating a single track (`LoopMode.one`), Resonance now re-uses the active media pipeline via `_audioHandler.seek(Duration.zero)` and `play()` instead of tearing down and recreating the player. Eliminates native Android `AudioTrack` destruction/re-instantiation and Windows `libmpv` demuxer cache flushes.
  - **Queue Lookahead Identity Isolation**: Updated `QueueService.nextTrack()`, `peekNextTrack()`, and `peekAhead()` to check `LoopMode.one` and return the current track rather than advancing into subsequent tracks.
  - **Prefetch Freeze on Repeat & Sleep End-of-Track**: `GaplessPrefetchService` automatically freezes secondary waterfall workers and suppresses N+1 and N+2 stream pre-caching when single-track loop or sleep timer End-of-Track is active, saving CPU cycles, network data, and battery life.

- **🛡️ Audio Pipeline Hardening & Filter Graph Coordination**:
  - **Filter Graph Collision Prevention**: Unified `loudnorm` and `equalizer` audio filters into a coordinated filter graph in `stream_resolution_service.dart`. Toggling the graphic equalizer no longer clobbers loudness normalization.
  - **Windows MPV FFmpeg Compatibility**: Detected and handled Windows embedded FFmpeg lacking native `loudnorm` filters, stripping the filter gracefully to prevent native playback crashes.
  - **Background Isolate Metadata Extraction**: Offloaded synchronous audio tag and embedded cover art extraction in `importExternalAudioFiles` to background isolates via Flutter `compute()`, ensuring the UI thread never hitches when importing large local music libraries.
  - **Off-Main-Looper Cipher Deobfuscation**: Dispatched Android YouTube cipher deobfuscation (`CipherDeobfuscator.prewarm`, `generatePoToken`, `decipherSignature`, `decipherN`) off the Android main UI thread to `Dispatchers.Default`.
  - **MediaSession Position Broadcast Throttling**: Throttled OS notification position broadcasts in `audio_handler.dart` to trigger on track changes, play/pause, and manual seeks, eliminating high-frequency IPC spam.

- **💾 Cache Eviction Concurrency & In-Flight Download Protection**:
  - **In-Flight Download Protection**: Filtered `.tmp` files in `CacheManager._scanAndSortFiles()` to prevent in-progress streaming downloads from being counted toward the disk cache limit or evicted prematurely.
  - **Atomic File Stat Resiliency**: Replaced multi-step synchronous filesystem queries with a single, safe `statSync()` enclosed in try-catch blocks. In-memory record caching eliminates `PathNotFoundException` (errno 2) crashes when streams complete and rename concurrently.
  - **Purge SQLite Cache on Maintenance**: Added `DefaultCacheManager().emptyCache()` to settings cache purge operations to thoroughly clear both network and disk image caches.

- **💬 Discord RPC Search Resiliency & Auto-Recovery**:
  - **Permutation Search Resiliency**: Scoped try/catch error handling inside query candidate permutation loops with extended timeouts (10s for album art, 8s for metadata). High-latency network spikes on initial queries now log warnings and gracefully fall through to alternative queries rather than aborting presence updates.
  - **Auto-Recovery Loop**: Wrapped Windows IPC pipe writes in exception handlers and implemented a throttled 30-second background reconnection loop to automatically restore Discord Rich Presence whenever the Discord desktop client restarts.

- **🎶 Lyrics Offset Hold-to-Accelerate & UI Polish**:
  - **Hold-to-Accelerate Offset Control**: Rewrote `LyricsOffsetControl` with an instant-response `_HoldAccelerateButton` using low-latency `Listener` pointers. Single taps adjust offset by $\pm 0.5\text{s}$, while holding activates a 3-speed acceleration curve (reaching $\pm 2.0\text{s}$ per tick for rapid adjustments). Includes a one-tap center badge reset to `0.0s`.
  - **Lyrics Gesture Isolation**: Enclosed offset controls inside opaque gesture detectors, preventing tap events from propagating to parent cards or unintentionally toggling fullscreen views. Decoupled track change detection from offset changes to prevent accidental queue resets.
  - **Desktop Scrollbar Consistent Sizing**: Locked desktop scrollbars to a constant 4.0dp thickness in both light and dark themes, eliminating awkward thickness swelling on hover while preserving smooth alpha opacity transitions (0.25 to 0.60).
  - **Blocked Tracks UI De-Slop**: Cleaned up the Blocked Tracks section by gating summary banners and search inputs behind non-empty checks. Replaced security shield icons with music-contextual `UIcons.regular.music_slash` and introduced a responsive guidance pill.
  - **Instant-Cut Miniplayer Transition**: Replaced `AnimatedSwitcher` in `BlurTransitionLayer` with instant 100% solid opacity and added window width guards to eliminate layout squishing and opacity flicker when entering miniplayer mode.

- **🧹 Dead Code Purge & Clean Settings**:
  - **Erased Obsolete Stream Engine Selector**: Removed the non-functional "Default Source" dropdown from Network Settings and pruned dead `streamSource` properties from `DownloadSettings` and Riverpod state. The app automatically and seamlessly resolves audio streams per-platform (automated InnerTube on Android, native Python IPC daemon on Windows).
  - **Third-Party Bloatware Pruned**: Removed deprecated dependencies `cupertino_icons`, `sqlite3_flutter_libs`, `tray_manager`, and `nativeapi` from `pubspec.yaml`, eliminating unnecessary binary overhead.

- **🐍 Python Downloader Engine Rebuild & Dependency Updates**:
  - **Recompiled Native Downloader Engine**: Recompiled `resonance_downloader.exe` (23.7 MB) using PyInstaller with upgraded core libraries: `yt-dlp` (`2026.8.19`), `requests` (`2.34.2`), `certifi` (`2026.7.22`), and `urllib3` (`2.8.0`). Injected Windows PE version metadata `1.0.0.15`.
  - **Fast Proof-of-Origin Token Generation**: Integrated `bgutil-pot-windows-x86_64.exe` (v0.8.1) for reliable `<1s` Proof-of-Origin token generation.
  - **Socket Timeout Hardening**: Configured strict socket timeouts (`8s` warmup, `15s` stream resolution) in `resonance_downloader.py`, preventing 240s+ socket hangs when encountering YouTube CDN throttling.
  - **Flutter & Dart Dependency Maintenance**: Upgraded core project dependencies including `flutter_riverpod` (`3.4.3`), `dio` (`5.11.1`), `audio_metadata_reader` (`1.8.1`), `flutter_local_notifications` (`22.3.2`), and `flutter_cache_manager` (`3.4.5`).

- **📦 Clean Baseline Packaging (Zero Delta Patching)**:
  - **Clean Baseline Installer**: For the official `v1.0.0` release, Windows delta patches (`.patch`) are intentionally omitted. Users receive the full, verified Inno Setup installer (`Resonance-v1.0.0-Windows.exe`) or standalone portable zip, establishing a 100% clean baseline without lingering beta artifacts. Future minor updates (`v1.0.1+`) will delta patch directly against this `v1.0.0` baseline.

- **🔢 Automated Test Verification & Stability Certification**:
  - **Continuous Live Audit Verified**: Completed extensive 7-Hour continuous playback audit and 30-minute live Sleep Timer audit with zero unhandled exceptions, zero playback stops, and constant bounded RAM.
  - **100% Automated Test Suite Passing**: Verified 0 analyzer issues (`dart analyze lib/`) and 100% passing test coverage across all unit and widget test suites (including newly added suites for sleep timer countdown, repeat-one audio guards, and download settings).

