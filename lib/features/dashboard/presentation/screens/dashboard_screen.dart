import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resonance/features/home/presentation/screens/home_screen.dart';
import 'package:resonance/features/download/presentation/screens/download_screen.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_screen.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance/features/library/presentation/screens/library_screen.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/docked_mini_player.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:resonance/core/providers/overlay_provider.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/features/explore/presentation/screens/explore_screen.dart';
import 'package:resonance/features/player/presentation/screens/now_playing_screen.dart';
import 'package:resonance/core/application/services/permission_service.dart';
import 'dart:io';
import 'package:resonance/features/tray/application/tray_service.dart';
import 'package:resonance/features/player/application/services/audio_orchestrator.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/app_sidebar.dart';
import 'package:resonance/features/dashboard/presentation/widgets/app_bottom_nav_bar.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {

  @override
  void initState() {
    super.initState();

    // Pindah ke sini agar memiliki context di bawah MaterialApp (MaterialLocalizations tersedia)
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

  List<Widget> _getScreens(bool isDesktop) {
    if (isDesktop) {
      return [
        const HomeScreen(), // 0
        const ExploreScreen(), // 1
        const LibraryScreen(), // 2
        const PlaylistScreen(), // 3
        const DownloadScreen(), // 4
        const SettingsScreen(), // 5
      ];
    }
    // On Mobile, Playlists is merged into Library.
    // Length must be 6 to prevent RangeError when resizing from Desktop index 5.
    return [
      const HomeScreen(), // 0
      const ExploreScreen(), // 1
      const LibraryScreen(), // 2
      const LibraryScreen(), // 3 (Playslists Redirection/Merge)
      const DownloadScreen(), // 4
      const SettingsScreen(), // 5
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Check if device is a large screen (Desktop/Tablet)
    final bool isDesktop = MediaQuery.of(context).size.width > 600;
    final bool showLyrics = ref.watch(lyricsOverlayProvider);
    final bool showNowPlaying = ref.watch(nowPlayingOverlayProvider);
    final logicalIndex = ref.watch(mainNavigationProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final nowPlayingTitle = currentTrack != null
        ? '${currentTrack.title} - ${currentTrack.artist ?? "Unknown"}'
        : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if (isDesktop) CustomTitleBar(nowPlayingTitle: nowPlayingTitle),
          Expanded(
            child: Row(
              children: [
                if (isDesktop) const AppSidebar(),

                // Main Content area
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        // 1. Base Layer: Screen Navigation
                        SafeArea(
                          top: true,
                          bottom: false,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              key: ValueKey('main_page_$logicalIndex'),
                              child: _getScreens(isDesktop)[logicalIndex],
                            ),
                          ),
                        ),

                        // 2. Mid Layer: Now Playing (Slide transition)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          },
                          child: showNowPlaying
                              ? const NowPlayingScreen(
                                  key: ValueKey('now_playing'),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('now_playing_empty'),
                                ),
                        ),

                        // 3. Top Layer: Lyrics Overlay
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: showLyrics
                              ? Container(
                                  key: const ValueKey('lyrics_overlay'),
                                  color: Colors.black.withValues(alpha: 0.6),
                                  child: const LyricsScreen(isEmbedded: true),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('lyrics_empty'),
                                ),
                        ),
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
      bottomNavigationBar: isDesktop ? null : const AppBottomNavBar(),
    );
  }
}
