### What's New in v0.1.8-beta (Build 13)

- **🎛️ Studio Equalizer Overhaul & 22 Acoustic Presets (Build 13 Update)**:
  - **22 Studio Acoustic Presets**: Expanded preset library from 10 (4 displayed) to 22 studio acoustic presets spanning 5 categorized profiles:
    - **General**: `Flat`, `Custom`.
    - **Bass**: `Bass Boost`, `Deep Bass`, `Sub Bass`, `Bass Reducer`.
    - **Voice & Speech**: `Vocal Booster` (with backwards-compatible `Vocal` alias), `Spoken Word`, `Treble Boost`, `Treble Reducer`.
    - **Music Genres**: `Hip Hop`, `R&B`, `Rock`, `Pop`, `Dance`, `Electronic`, `Metal`.
    - **Acoustic & Instruments**: `Acoustic`, `Classical`, `Jazz`, `Piano`, `Lounge`, `Latin`.
  - **Interactive Real-Time Bézier Curve Visualizer**: Real-time Catmull-Rom cubic Bézier frequency response curve (`EqualizerCurveVisualizer`) showing the active sound curve across 9 bands (`62.5 Hz` to `16 kHz`). Features a glowing primary accent line, zero dB reference dashed guide, vertical gradient fill, and smooth 240ms tween animation when switching presets.
  - **1-Tap Preset Carousel & Categorized Modal**: Replaced legacy dropdown with a horizontal scrollable chip row for fast 1-tap switching (`EqualizerPresetSelector`) and an "All (22)" categorized modal sheet with live search filtering.
  - **Adaptive 9-Band Sliders Console**: Vertical sliders with dynamic decibel readout badges (`+3.5 dB`, `0 dB`, `-4.0 dB`) highlighted with theme accent. Automatically adapts to screen size:
    - **Android Mobile**: Enables silky horizontal scrolling with comfortable 48dp touch targets on narrow viewports (`<44dp` per band) to prevent accidental touch overlap.
    - **Desktop & Tablets**: Expands evenly across the modal width (`>=44dp` per band) for a unified console view.
  - **Glassmorphic Floating Container**: Migrated to `FloatingSheetShell` with backdrop blur, drag handle, quick 'Reset to Flat' button, master power switch (`ResonanceSwitch`), and linked slider checkbox.

- **⚡ Zero-Flicker Screen Persistence & Image Cache Optimization (Build 13 Update)**:
  - **Instant Screen Switching**: Replaced `AnimatedSwitcher` with `IndexedStack` in `dashboard_screen.dart`. All screens (Home, Explore, Library, Settings) stay mounted in memory — switching tabs is 0ms instant, scroll positions are permanently preserved, and 0 redundant network re-fetches occur when moving between pages.
  - **Card Resolution Caching**: Introduced `ThumbnailUtils.toCardResolution(url)` targeting `=w400-h400-l90-rj` (or `hqdefault.jpg`) for feeds, cards, and list tiles. Reduces image network payload by ~90% (35KB vs 400KB) and decoded bitmap RAM by ~86% (~640KB vs 4.66MB), eliminating Android image cache churn. High-res 1080p is reserved strictly for full-screen player artwork.
  - **Synchronous Artwork Initialization**: Bound thumbnail resolution synchronously in `media_artwork_widget.dart`'s `initState()`, completely eliminating initial blank placeholder flicker.
  - **Desktop Disk Caching**: Initialized `sqflite_common_ffi` on Windows and Linux, giving desktop platforms permanent SQLite database caching for image files. Expanded Android RAM cache from 40MB/100 images to 128MB/250 images.

- **🔔 Android Notification Placement & Mobile Symmetrical Layout (Build 13 Update)**:
  - **Safe-Area Top Offset**: Fixed Android status bar clipping in `notification_banner_overlay.dart` with responsive safe-area offset (`topSafe + 10` on mobile) and symmetrical centering.
  - **De-Pyramidized Clean Architecture**: Refactored monolithic 11-level pyramid overlay into modular `_BannerCard`, `_BannerTextContent`, and `_BannerActionButton`.
  - **Positive 31-bit Integer Notification IDs**: Masked notification IDs to `(id.hashCode & 0x7FFFFFFF)` in `notification_provider.dart`, eliminating sticky ongoing notification flags on Transsion XOS/HiOS and Xiaomi MIUI/HyperOS devices.
  - **Docked Mini-Player Bezel Clearance**: Added 12dp right bezel padding and horizontal auto-scrolling `ResonanceMarqueeText` to ensure controls and song titles are never clipped by curved mobile screen corners.

- **🤖 Inaugural Android Beta Release**:
  - **First Official Android Launch**: `v0.1.8-beta` marks the official debut of Resonance on Android as a public beta release! All desktop-class features — online streaming, offline caching, and playlist management — are now fully available on mobile devices.
  - **Native Headless PoToken Solver**: Built from the ground up for mobile with a zero-dependency Kotlin WebView engine (`PoTokenGenerator.kt`, `PoTokenWebView.kt`, `yt.solver.core.js`). Generates verified YouTube BotGuard tokens internally without needing any external Python or desktop background processes.
  - **Background Playback & Lock Screen Controls**: Seamless native Android audio service integration with media session notification controls, artwork rendering, and audio focus handling during calls and external interrupts.
  - **Active Beta Testing Phase**: Because this is the first public Android release, testing is actively ongoing across various Android OS versions (Android 10 through 15) and OEM skins (OneUI, HyperOS/MIUI, ColorOS, Pixel). Users are encouraged to report any device-specific quirks or playback behavior on GitHub Issues.

- **Windows 11/10 Taskbar & Start Menu Jump List Integration**:
  - **Native Win32 Shell COM Engine**: Implemented `windows/runner/jump_list.cpp` and `jump_list.h` utilizing `ICustomDestinationList`, `IObjectCollection`, and `IShellLinkW` (linked against `propsys.lib`). Dynamically populates custom taskbar and Start Menu jump lists with **Recently Played** tracks and **Quick Picks**.
  - **Quick Action Tasks**: Added system-level tasks for instantaneous media control: Play/Pause (`--toggle-play`), Next Track (`--next-track`), Open Liked Songs (`--liked-songs`), and Focus Search (`--search`).
  - **Single-Instance IPC Command Forwarding**: Extended `main.cpp` and `flutter_window.cpp` with `WM_COPYDATA` handling. When launching tasks or clicking jump list items while Resonance is running or minimized to tray, command-line arguments are forwarded to the existing instance without spawning duplicate processes.
  - **Debounced Dart Service**: Created `WindowsJumpListService` in `lib/features/stream/platform/windows/windows_jump_list_service.dart` with a 3-second debounce window to prevent disk I/O thrashing during rapid song skips.

- **Platform-Decoupled Stream Resolution & Android Native PoToken Solver**:
  - **Architecture Modernization**: Extracted stream resolution into a dedicated, clean domain layer (`lib/features/stream/`) with `IPlatformStreamResolver` and `IPlatformPoTokenService` interfaces, isolating platform-specific playback logic from general repositories.
  - **Android Native BotGuard / PoToken Solver**: Added Kotlin headless `PoTokenWebView` generator (`PoTokenGenerator.kt`, `PoTokenWebView.kt`, `yt.solver.core.js`, `astring.js`, `meriyah.js`) in `android/app/src/main/kotlin/com/chronostudio/resonance/potoken/`. Generates verified InnerTube BotGuard and PoToken pairs natively on Android without requiring external Python binaries.
  - **Windows Python Stream Bridge**: Maintained robust streaming on Windows via Python engine bridge with automated token refresh and playback session tracking (`PlaybackSession`, `PoTokenPair`, `StreamResolutionResult`).

- **Unified Home Feed & Explore Search Overhaul**:
  - **Consolidated Home Feed**: Refactored the fragmented home experience into `UnifiedHomeFeed`, featuring an `AdaptiveHomeHeader`, `QuickPicksColumnSection` (3-column grid for dense desktop/mobile browsing), `SpeedDialSection`, and `HomeCachedMusicSection`.
  - **Sub-page Elimination**: Removed obsolete sub-pages (`artist_sub_page.dart`, `playlist_sub_page.dart`, `recent_sub_page.dart`) and migrated their functionality into dynamic, filterable sections.
  - **Search Overhaul**: Implemented `RecentSearchesProvider` with persistent local history, horizontal carousel preview (`RecentSearchesCarouselSection`), real-time search query suggestions (`SearchSuggestionsSection`), and mood/genre chips (`MoodGenreSection`).

- **Settings Redesign & About Card Update Hub**:
  - **Integrated Update Experience**: Relocated the standalone update section into the primary `AboutCard` (`about_card.dart`). Added dynamic status badge chip (`_AboutCardVersionBadge`) that transitions smoothly between checking spinner, update available dot, up-to-date badge, and "Restart to Update" chip.
  - **Design System Button Alignment**: Integrated `ResonanceButton` for "Check for Updates" and "Release Notes", parameterizing height and padding for pixel-perfect alignment.
  - **Support Me Visual Polish**: Realigned `SettingsDropdownTile` typography with standardized `13px` title, `11px` subtitle, and `dense: true` to prevent oversized gaps.
  - **StickySubViewLayout**: Fixed header duplication across nested settings sub-screens using persistent `StickySubViewLayout`.
  - **Blocked Tracks Management**: Added `BlockedTracksSection` and `BlockedTracksSheet` to view, manage, and unblock tracks excluded from playback.

- **Smart Download Manager & Input Auto-Detection**:
  - **Heuristic URL Classifier**: Introduced `DownloadInputDetector` (`download_input_detector.dart`) to automatically identify YouTube Music tracks, standard YouTube videos/shorts, playlist URLs, and raw search queries.
  - **Streamlined UI**: Removed confusing manual radio selectors and legacy source pickers in `download_screen.dart`. Removed inaccurate desktop Python bridge warnings on Android devices.

- **Dedicated Queue Screen & Auto-Continue / Auto-Cache**:
  - **Standalone Queue Manager**: Added full-screen `QueueScreen` (`queue_screen.dart`) featuring `ReorderableQueueList`, `QueueNowPlayingCard`, and dynamic buffer selector (`QueueBufferSelector`).
  - **Endless Auto-Continue**: Added `PlaylistAutoContinueProvider` and toggle button to automatically query related streams and continue playback seamlessly when reaching the end of the queue.
  - **Background Auto-Cache**: Implemented `PlaylistAutoCacheProvider` and `PlaylistStreamCacheHandler` to automatically pre-cache online playlist tracks for offline playback in the background.

- **Android Modernization & Store Compliance**:
  - **Battery Optimization Removal**: Purged invasive `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission from `AndroidManifest.xml` and removed battery prompt dialogues to ensure compliance with Google Play Store policies.
  - **Notification Permissions**: Integrated runtime permission handling for Android 13+ (`POST_NOTIFICATIONS`) within `PermissionService`.
  - **Release Keystore Setup**: Added `android/key.properties.example` template and configured signing configs in `android/app/build.gradle.kts`.

- **Responsive Design System & Tokens**:
  - **AppBreakpoints**: Centralized layout breakpoints (`isMobile`, `isTablet`, `isDesktop`) across screens.
  - **ResonanceSegmentedBar**: Created glassmorphic animated tab selector (`resonance_segmented_bar.dart`) for responsive mobile navigation.
  - **Mini-Player Refinements**: Polished docked and floating player controls, responsive artwork sizing, and refined volume popup dialog (`VolumePopupDialog`).

- **Maintenance & Version Bump**:
  - Bumped version to `0.1.8-beta+13` across `pubspec.yaml`, `.github/workflows/release.yml`, and `python_engine/version_info.txt` (numeric `0.1.8.13`).
  - Build number incremented monotonically from `+12` → `+13`.
  - Added comprehensive automated test suite across all new services, providers, and UI widgets (100/100 tests passing).

---

### 📦 Which file should I download?

| Platform / Device | File to Download | Approximate Size | Description |
| :--- | :--- | :--- | :--- |
| **Android (Modern Phones)** | `Resonance-v0.1.8-beta.13-Android-64bit-arm64.apk` | **~33 MB** | **Recommended for 99% of Android devices** (Samsung, Xiaomi, Pixel, Oppo, Vivo, etc. made after 2017). |
| **Android (Older Devices)** | `Resonance-v0.1.8-beta.13-Android-32bit-v7a.apk` | **~29 MB** | For older 32-bit Android phones and legacy tablets. |
| **Android (All Devices)** | `Resonance-v0.1.8-beta.13-Android-Universal.apk` | **~92 MB** | Universal fallback containing all CPU architectures. |
| **Windows 10 / 11** | `Resonance-Setup-v0.1.8-beta.exe` | **~97 MB** | Recommended full installer with bundled FFmpeg, desktop shortcut, and Start Menu integration. |
| **Windows Portable** | `Resonance-v0.1.8-beta-Windows-Portable.zip` | **~124 MB** | Standalone portable zip — extract and run without installation. |
| **Windows Delta Patch** | `Resonance-...-to-v0.1.8-beta...delta.patch` | **< 26 MB** | Lightweight binary update patch for existing installations. |

---

> 📱 **Android Beta Notice**: This is the inaugural public beta release of Resonance for Android. If installing via APK, allow installation from unknown sources. Because this is an active beta test, please report any device-specific playback quirks or background interruptions via GitHub Issues.  
> ℹ️ **Unsigned Build Notice (Windows)**: Code-signing certificate approval is pending. If SmartScreen appears on Windows, click **More info → Run anyway**.
