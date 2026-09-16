### What's New in v0.1.9-beta (Build 14)

- **🛡️ Offline Playback Resiliency & Offline Radio Fallback**:
  - **Cascading Skip Protection**: Eliminated the rapid domino skip loop that wiped through queue songs when a device lost internet connectivity. Preserved `OfflinePlaybackException` through `PlaybackArchitectureService` and `StreamResolutionService` so playback halts gracefully instead of rapidly cycling tracks.
  - **Cached Stream Music Offline Radio Fallback**: When an online queue or radio runs out of playable cached songs offline, Resonance automatically calls `QueueOrchestrator.playOfflineRadioFallback()`. It dynamically populates the queue from your verified local cache and cached stream music collection, keeping music playing indefinitely without dead silence.
  - **Background Services Offline Guards**: Added network connectivity guards to secondary background workers (Discord RPC iTunes queries, SMTC notification artwork downloads via `flutter_cache_manager`, Gapless Prefetch timers, and YouTube recommendation workers). When offline, these services return immediate cached fallbacks without firing unhandled DNS lookups or spamming `SocketException`.

- **🔍 YouTube Music-Style Desktop Search Bar & History Dropdown**:
  - **Flush Morphing Dropdown Overlay**: Re-engineered the desktop search bar into a unified YouTube Music-style container. When the search history dropdown opens, the search input's bottom corners flatten (`0dp`) while the dropdown attaches flush at `Offset(0, -1)` with matching rounded bottom corners (`10dp`) and solid `surfaceContainerHigh` background.
  - **TapRegion Outside Click Dismissal**: Replaced timer-based dismissal with Flutter native `TapRegion` on both search input and history overlay. Clicking anywhere outside instantly dismisses the dropdown with 0ms lag.
  - **Top-Left Flash Elimination**: Resolved unlinked layer detachment where switching tabs while search history was open caused the dropdown to flash at `(0, 0)` in the top-left corner.
  - **Search History Management**: Added counter-clockwise history icons (`UIcons.regular.time_past`), text truncation, and individual trash can delete actions (`UIcons.regular.trash`) to easily remove specific items from search history.

- **📱 Mobile Search Bar Clear vs Cancel UX & Query Editability**:
  - **Inline Clear Icon**: Added an inline `[✕]` (`UIcons.regular.cross_small`) inside search fields across Explore, Home, and Library screens on mobile. Tapping clears entered text while keeping the keyboard focused and search mode active.
  - **Dedicated Cancel Button**: Replaced confusing toggle actions with an explicit `"Cancel"` button that dismisses the keyboard, restores previous view tabs, and clears active search state cleanly.
  - **Live Filtered History & Query Editability Fix**: Fixed a bug where editing an existing search query wiped keystrokes on every character. Replaced imperative clobbering with reactive `ref.listen` and added `MobileSearchHistorySection` for live real-time history filtering while typing.

- **🚀 Android Now Playing Scroll Smoothness & Physics Overhaul**:
  - **Native Clamping Scroll Physics**: Replaced conflicting `BouncingScrollPhysics` with native `ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` on Android across `NowPlayingScreen`, `FluentScrollBehavior`, and `LyricsListView`.
  - **Eliminated Double-Bounce Conflict**: Solved the issue where iOS-style spring simulation fought Android 12+ `StretchingOverscrollIndicator`, which previously caused the screen to bounce and jitter endlessly without coming to rest.
  - **Adaptive Track Info Layout**: Implemented `LayoutBuilder` in `MetadataCard` to inspect viewport constraints:
    - **Finite Constraints** (Desktop 240px `SizedBox` or Fullscreen `Expanded`): Enables smooth scrolling (`SilkySingleChildScrollView` on desktop, `SingleChildScrollView` on mobile), completely eliminating 18px `RenderFlex` overflow errors.
    - **Infinite Constraints** (Mobile portrait `SingleChildScrollView`): Renders the column directly without a nested scrollview, preventing pointer gesture hijacking over track info.

- **🎵 UI/UX Queue Polish & Animated Next-in-Queue Titles**:
  - **Clean Ordinal Queue Numbering**: Replaced legacy `N+1`, `N+2` queue indicators with clean, intuitive ordinal numbers (`1`, `2`, `3`).
  - **Simplified Queue Header**: Removed obsolete `N+20` buffer dropdown from the top-right corner of the queue screen, streamlining queue controls.
  - **Animated Long Titles**: Integrated auto-scrolling `ResonanceMarqueeText` into `NextInQueueCard`. When track titles exceed card width, they smoothly auto-scroll horizontally after a 2-second pause, eliminating awkward `...` text cutoffs.
  - **Standardized Media Actions Button**: Upgraded media actions button from vertical dots to horizontal three dots (`UIcons.regular.menu_dots`) and aligned its position to the far right edge across the desktop mini-player, Now Playing top bar, and Fullscreen audio view.
  - **Android Dynamic Import Playlist Sheet**: Added an interactive file picker button to `ImportPlaylistSheet` on Android where drag-and-drop is unsupported, matching the library import workflow.

- **🖼️ Music Card Thumbnail Aspect Ratio & Blocked Music System**:
  - **Natural 16:9 Artwork Cropping**: Removed rigid height overrides from `MediaArtworkWidget` and mapped YouTube stream artwork to clean 16:9 `mqdefault.jpg` via `ThumbnailUtils.toCardResolution()`, eliminating pillarbox side bars and blurred letterboxing without distorting square 1:1 albums.
  - **Consolidated Artwork Caching**: Eliminated duplicate artwork downloads between `PlaybackSyncService` and `DiscordRpcService`, consolidating image retrieval into `AudioMetadataService._upgradeToHighResArt()`.
  - **Comprehensive Blocked Music Filtering**: Shielded feeds (`LocalQuickPicksSection`, `HomeCachedMusicSection`, `HomeRecentPlaysSection`, `RecentSearchesCarouselSection`, and offline radio pools) from displaying blocked songs, with immediate toast feedback when attempting direct playback.
  - **Discord RPC Auto-Recovery**: Wrapped Discord IPC pipe writes in try-catch blocks to prevent crashes when Discord exits, adding a 30-second background reconnection loop to automatically restore Rich Presence when Discord reopens.

- **📦 Local Packaging Scripts & CI/CD Pipeline Synchronization**:
  - **Proposal B Android Binaries**: Synchronized `scripts/package_android.ps1` to produce standardized split-per-ABI APKs (`Resonance-v0.1.9.14-Android-64bit-arm64.apk`, `Resonance-v0.1.9.14-Android-32bit-v7a.apk`, `Resonance-v0.1.9.14-Android-Universal.apk`).
  - **Windows Packaging Automation**: Updated `scripts/package_windows.ps1` to automatically compile the Python downloader engine with PyInstaller, verify FFmpeg runtime binaries, clear asset caches, and build the Inno Setup installer.
  - **Unified Build Runner**: Enhanced `scripts/package_all.ps1` with `-Platform`, `-SkipPythonEngine`, `-SkipInstaller`, and `-BuildAppBundle` switches for fast local testing.
  - **Windows Installer Elevation Fix**: Added `PrivilegesRequiredOverridesAllowed=dialog` to `windows/resonance_installer.iss`, allowing users to install cleanly into `Program Files` without permission failures or version collisions with `%LOCALAPPDATA%`.

- **🔢 Version Bump**:
  - Bumped version to `0.1.9-beta+14` across `pubspec.yaml`, `python_engine/version_info.txt` (numeric `0.1.9.14`), `windows/resonance_installer.iss`, and local packaging scripts.
  - Build number incremented monotonically from `+13` → `+14`.
  - Automated test suite verified (100% passing across player, explore, library, and core modules).
