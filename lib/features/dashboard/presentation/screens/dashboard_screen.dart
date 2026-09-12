import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resonance/core/application/services/permission_service.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/app_bottom_nav_bar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/app_sidebar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/notification_banner_overlay.dart';
import 'package:resonance/features/download/presentation/screens/download_screen.dart';
import 'package:resonance/features/explore/presentation/screens/explore_screen.dart';
import 'package:resonance/features/home/presentation/screens/home_screen.dart';
import 'package:resonance/features/library/presentation/screens/library_screen.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/services/audio_orchestrator.dart';
import 'package:resonance/features/player/presentation/screens/now_playing_screen.dart';
import 'package:resonance/features/player/presentation/screens/queue_screen.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/docked_mini_player.dart';
import 'package:resonance/core/providers/search_provider.dart';
import 'package:resonance/features/home/presentation/providers/home_navigation_provider.dart';
import 'package:resonance/features/library/presentation/widgets/morphing_library_bar.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_screen.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance/features/tray/application/tray_service.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await PermissionService.requestInitialPermissions(context);
      });
    }

    // This connects all reactive background services (Sync, Tracking, Maintenance, Restoration)
    // without polluting the UI Layer.
    ref.read(audioOrchestratorProvider);

    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(trayServiceProvider).initTray();
      });
    }
  }

  List<Widget> _getScreens(bool isWideLayout) {
    if (isWideLayout) {
      return const [
        HomeScreen(), // 0
        ExploreScreen(), // 1
        LibraryScreen(), // 2
        PlaylistScreen(), // 3
        DownloadScreen(), // 4
        SettingsScreen(), // 5
      ];
    }
    // On Mobile/Compact: Unified HomeScreen (with adaptive search header),
    // ExploreScreen (Dedicated Explore & Discovery),
    // LibraryScreen (with Playlists and Downloads merged into 1 & 2),
    // SettingsScreen (at 5). Length is 6 to prevent RangeError during resize/redirection.
    return const [
      HomeScreen(), // 0 (Home Feed)
      ExploreScreen(), // 1 (Dedicated Explore & Discovery)
      LibraryScreen(), // 2 (Library)
      LibraryScreen(), // 3 (Playlists Redirection -> Library)
      LibraryScreen(), // 4 (Downloads Redirection -> Library)
      SettingsScreen(), // 5 (Settings)
    ];
  }

  bool _handleBackPress() {
    // 0. Dismiss Queue Overlay
    final showQueue = ref.read(queueOverlayProvider);
    if (showQueue) {
      ref.read(queueOverlayProvider.notifier).setVisible(false);
      return true;
    }

    // 1. Dismiss Lyrics Overlay
    final showLyrics = ref.read(lyricsOverlayProvider);
    if (showLyrics) {
      ref.read(lyricsOverlayProvider.notifier).toggle();
      return true;
    }

    // 2. Dismiss Now Playing Screen
    final showNowPlaying = ref.read(nowPlayingOverlayProvider);
    if (showNowPlaying) {
      ref.read(nowPlayingOverlayProvider.notifier).setVisible(false);
      return true;
    }

    // 3. Dismiss Playlist Detail View if active
    final selectedPlaylist = ref.read(selectedPlaylistIdProvider);
    if (selectedPlaylist != null) {
      ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(null);
      return true;
    }
    final selectedHomePlaylist = ref.read(selectedHomePlaylistProvider);
    if (selectedHomePlaylist != null) {
      ref.read(selectedHomePlaylistProvider.notifier).setSelectedId(null);
      return true;
    }

    // 4. Dismiss Settings SubView if in a sub-section
    final settingsSubView = ref.read(settingsSubViewProvider);
    if (settingsSubView != SettingsSubView.none) {
      ref.read(settingsSubViewProvider.notifier).close();
      return true;
    }

    // 5. Dismiss Library Downloads Mode if active
    final libraryMode = ref.read(libraryNavModeProvider);
    if (libraryMode == LibraryNavMode.downloads) {
      ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.music);
      return true;
    }

    // 6. Dismiss Search Query if active
    final searchQuery = ref.read(searchQueryProvider);
    if (searchQuery.isNotEmpty) {
      ref.read(searchQueryProvider.notifier).clear();
      return true;
    }

    // 7. Return to Home Tab if on another tab
    final logicalIndex = ref.read(mainNavigationProvider);
    if (logicalIndex != 0) {
      ref.read(mainNavigationProvider.notifier).setIndex(0);
      return true;
    }

    // 8. Double tap back to exit app
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ref.read(notificationProvider.notifier).showNotification(
        'Exit Resonance',
        'Press back again to exit Resonance',
        silentOsNotification: true,
      );
      return true;
    }

    return false; // Allow app exit
  }

  @override
  Widget build(BuildContext context) {
    // Standardized AppBreakpoints for responsive geometry vs OS platform checks
    final bool isWideLayout = AppBreakpoints.isWide(context);
    final bool isDesktopOs =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final bool isAndroid = Platform.isAndroid;
    final bool showLyrics = ref.watch(lyricsOverlayProvider);
    final bool showQueue = ref.watch(queueOverlayProvider);
    final bool showNowPlaying = ref.watch(nowPlayingOverlayProvider);
    final logicalIndex = ref.watch(mainNavigationProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final nowPlayingTitle = currentTrack != null
        ? '${currentTrack.title} - ${currentTrack.artist ?? "Unknown"}'
        : null;

    return PopScope(
      canPop: !isAndroid,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final handled = _handleBackPress();
        if (!handled && isAndroid) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: !isDesktopOs,
        body: Column(
          children: [
            if (isDesktopOs) CustomTitleBar(nowPlayingTitle: nowPlayingTitle),
            Expanded(
              child: Row(
                children: [
                  if (isWideLayout)
                    SafeArea(
                      top: !isDesktopOs,
                      bottom: false,
                      right: false,
                      child: const AppSidebar(),
                    ),

                  // Main Content area
                  Expanded(
                    child: ClipRect(
                      child: Stack(
                        children: [
                          // 1. Base Layer: Screen Navigation
                          _ScreenNavigationLayer(
                            isDesktopOs: isDesktopOs,
                            logicalIndex: logicalIndex,
                            currentScreen: _getScreens(isWideLayout)[logicalIndex],
                          ),

                          // 2. Mid Layer: Now Playing (Slide transition)
                          _NowPlayingSlideLayer(showNowPlaying: showNowPlaying),

                          // 3. Top Layer: Lyrics Overlay
                          _LyricsOverlayLayer(showLyrics: showLyrics),

                          // 4. Top Layer: Queue Overlay
                          _QueueOverlayLayer(showQueue: showQueue),

                          // 5. In-App Notification Toast Overlay (Top-Right Floating Banner)
                          const NotificationBannerOverlay(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Persist the Mini Player at the bottom of the body
            const DockedMiniPlayer(),
          ],
        ),
        bottomNavigationBar: isWideLayout ? null : const AppBottomNavBar(),
      ),
    );
  }
}

class _ScreenNavigationLayer extends StatelessWidget {
  final bool isDesktopOs;
  final int logicalIndex;
  final Widget currentScreen;

  const _ScreenNavigationLayer({
    required this.isDesktopOs,
    required this.logicalIndex,
    required this.currentScreen,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: !isDesktopOs,
      bottom: false,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey('main_page_$logicalIndex'),
          child: currentScreen,
        ),
      ),
    );
  }
}

class _NowPlayingSlideLayer extends StatelessWidget {
  final bool showNowPlaying;

  const _NowPlayingSlideLayer({required this.showNowPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      child: showNowPlaying
          ? const NowPlayingScreen(key: ValueKey('now_playing'))
          : const SizedBox.shrink(key: ValueKey('now_playing_empty')),
    );
  }
}

class _LyricsOverlayLayer extends StatelessWidget {
  final bool showLyrics;

  const _LyricsOverlayLayer({required this.showLyrics});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: showLyrics
          ? Container(
              key: const ValueKey('lyrics_overlay'),
              color: Colors.black.withValues(alpha: 0.6),
              child: const LyricsScreen(isEmbedded: true),
            )
          : const SizedBox.shrink(key: ValueKey('lyrics_empty')),
    );
  }
}

class _QueueOverlayLayer extends StatelessWidget {
  final bool showQueue;

  const _QueueOverlayLayer({required this.showQueue});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: showQueue
          ? Container(
              key: const ValueKey('queue_overlay'),
              color: Colors.black.withValues(alpha: 0.6),
              child: const QueueScreen(isEmbedded: true),
            )
          : const SizedBox.shrink(key: ValueKey('queue_empty')),
    );
  }
}
