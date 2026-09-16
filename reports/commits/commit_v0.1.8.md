Feat: Inaugural Android beta release, Windows Jump List, modular stream engine, unified home & explore feed, smart download detector, about card update hub, and version bump to 0.1.8-beta

• Inaugural Android Beta Release: official first public release of Resonance for Android under active beta testing; introduces native Kotlin headless WebView BotGuard/PoToken solver, media notification controls, and touch-optimized responsive layout
• Windows 11/10 Jump List & IPC: implement native Win32 COM jump list in jump_list.cpp with Recently Played, Quick Picks, and custom Tasks (Play/Pause, Next, Liked, Search) plus WM_COPYDATA command forwarding in flutter_window.cpp and debounced WindowsJumpListService
• Modular Stream Engine: decouple stream resolution into lib/features/stream/ with platform-specific resolvers; implement native Android headless WebView BotGuard/PoToken solver in Kotlin and Python engine streaming bridge on Windows
• Unified Home Feed: consolidate home view into UnifiedHomeFeed, AdaptiveHomeHeader, QuickPicksColumnSection, SpeedDialSection, and HomeCachedMusicSection; remove legacy artist/playlist/recent sub-pages
• Explore Search Overhaul: add RecentSearchesProvider, RecentSearchesCarouselSection, SearchSuggestionsSection, MoodGenreSection, and dual idle/searching states
• Settings & About Card Update Hub: merge app info card with update status badge and interactive check/restart actions in AboutCard; standardize ResonanceButton styling; align Support Me tile typography (dense 13px/11px); fix StickySubViewLayout double header
• Smart Download Detector: introduce DownloadInputDetector to automatically distinguish YouTube Music, YouTube videos, playlists, and search queries; remove manual source picker and misleading Android bridge warnings
• Dedicated Queue Screen & Auto-Continue: add standalone QueueScreen with ReorderableQueueList, buffer selector, and now playing banner; implement background playlist auto-caching and endless radio auto-continue
• Android Modernization & Permissions: remove invasive REQUEST_IGNORE_BATTERY_OPTIMIZATIONS for store compliance; handle Android 13+ POST_NOTIFICATIONS; add release key.properties signing configuration
• Design System & Responsive Layout: introduce AppBreakpoints, animated glassmorphic ResonanceSegmentedBar, MorphingLibraryBar, and volume dialog polish
• Version Bump: update version to 0.1.8-beta (+12) across pubspec.yaml, Inno Setup installer script (0.1.8.0), and Python engine version info (0.1.8.12)
