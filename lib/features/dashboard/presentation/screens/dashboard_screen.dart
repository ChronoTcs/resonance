import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/widgets/custom_title_bar.dart';
import 'package:resonance/features/home/presentation/screens/home_screen.dart';
import 'package:resonance/features/download/presentation/screens/download_screen.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_screen.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance/features/library/presentation/screens/library_screen.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/docked_mini_player.dart';
import 'package:resonance/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:resonance/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/features/explore/presentation/screens/explore_screen.dart';
import 'package:resonance/features/player/presentation/screens/now_playing_screen.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/application/services/permission_service.dart';
import 'dart:io';
import 'package:resonance/features/tray/application/tray_service.dart';
import 'package:resonance/features/player/application/services/audio_orchestrator.dart';
import 'package:resonance/core/widgets/glossy_animated_background.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  bool _isExtended = false;

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

    // Menerjemahkan index logis (0-5) ke index fisik BottomNavigationBar (0-4)
    int getPhysicalIndex(int logicalIndex) {
      if (!isDesktop) {
        if (logicalIndex == 3) return 2; // Playlists -> Library
        if (logicalIndex > 3) {
          return logicalIndex - 1; // Download (4->3), Settings (5->4)
        }
      }
      return logicalIndex;
    }

    // Menerjemahkan tap fisik (0-4) kembali ke index logis (0-5)
    int getLogicalIndex(int physicalIndex) {
      if (!isDesktop) {
        if (physicalIndex >= 3) {
          return physicalIndex + 1; // 3->4 (Download), 4->5 (Settings)
        }
      }
      return physicalIndex;
    }

    final logicalIndex = ref.watch(mainNavigationProvider);
    final physicalIndex = getPhysicalIndex(logicalIndex);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if (isDesktop) const CustomTitleBar(),
          Expanded(
            child: Row(
              children: [
                if (isDesktop) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isExtended ? 160 : 50,
                    color:
                        Theme.of(context).navigationRailTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hamburger Menu
                        Container(
                          height: 50,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 4),
                          child: ReusableHoverIconButton(
                            icon: UIcons.regular.waveform_path,
                            tooltip: _isExtended
                                ? 'Close Navigation'
                                : 'Open Navigation',
                            onTap: () {
                              setState(() {
                                _isExtended = !_isExtended;
                              });
                            },
                            iconSize: 20,
                            padding: 10,
                          ),
                        ),
                        // Navigation Items
                        Expanded(
                          child: Stack(
                            children: [
                               // Floating Active Indicator
                              if (logicalIndex != 5)
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  tween: Tween<double>(
                                    begin: logicalIndex * 38.0,
                                    end: logicalIndex * 38.0,
                                  ),
                                  builder: (context, value, child) {
                                    return Positioned(
                                      top: value + 2.0,
                                      left: 0,
                                      child: Container(
                                        width: 3,
                                        height: 34,
                                        margin: const EdgeInsets.only(left: 4),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              // Nav items list
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildNavItem(
                                      0,
                                      'Home',
                                      UIcons.regular.home,
                                      UIcons.solid.home,
                                    ),
                                    _buildNavItem(
                                      1,
                                      'Explore',
                                      UIcons.regular.compass_alt,
                                      UIcons.solid.compass_alt,
                                    ),
                                    _buildNavItem(
                                      2,
                                      'Library',
                                      UIcons.regular.headphones,
                                      UIcons.solid.headphones,
                                    ),
                                    _buildNavItem(
                                      3,
                                      'Playlists',
                                      UIcons.regular.list_music,
                                      UIcons.solid.list_music,
                                    ),
                                    _buildNavItem(
                                      4,
                                      'Download',
                                      UIcons.regular.download,
                                      UIcons.solid.download,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Settings Button positioned at the bottom of the rail with identical slide indicator animation
                        Container(
                          height: 38,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Stack(
                            children: [
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                tween: Tween<double>(
                                  begin: logicalIndex == 5 ? 0.0 : 38.0,
                                  end: logicalIndex == 5 ? 0.0 : 38.0,
                                ),
                                builder: (context, value, child) {
                                  if (value >= 34.0) return const SizedBox.shrink();
                                  return Positioned(
                                    top: value + 2.0,
                                    left: 0,
                                    child: Container(
                                      width: 3,
                                      height: 34,
                                      margin: const EdgeInsets.only(left: 4),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: _buildNavItem(
                                  5,
                                  'Settings',
                                  UIcons.regular.settings,
                                  UIcons.solid.settings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlossyAnimatedBackground(
                    isSelected: true,
                    borderRadius: BorderRadius.zero,
                    baseColor: Colors.transparent,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const SizedBox(
                      width: 1,
                      height: double.infinity,
                    ),
                  ),
                ],
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
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: physicalIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Theme.of(
                context,
              ).iconTheme.color?.withValues(alpha: 0.5),
              onTap: (int index) {
                ref
                    .read(mainNavigationProvider.notifier)
                    .setIndex(getLogicalIndex(index));
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(UIcons.regular.home),
                  activeIcon: Icon(UIcons.solid.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(UIcons.regular.compass_alt),
                  activeIcon: Icon(UIcons.solid.compass_alt),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(UIcons.regular.headphones),
                  activeIcon: Icon(UIcons.solid.headphones),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(UIcons.regular.download),
                  activeIcon: Icon(UIcons.solid.download),
                  label: 'Download',
                ),
                BottomNavigationBarItem(
                  icon: Icon(UIcons.regular.settings),
                  activeIcon: Icon(UIcons.solid.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _buildNavItem(
    int index,
    String title,
    IconData iconData,
    IconData selectedIconData,
  ) {
    final selectedIndex = ref.watch(mainNavigationProvider);
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);

    // In dark mode, primary is light. In light mode, primary is dark.
    final activeColor = theme.primaryColor;
    final inactiveColor = theme.iconTheme.color!.withValues(alpha: 0.5);
    final color = isSelected ? activeColor : inactiveColor;

    final button = ReusableHoverIconButton(
      icon: isSelected ? selectedIconData : iconData,
      tooltip: title,
      onTap: () {
        ref.read(mainNavigationProvider.notifier).setIndex(index);
      },
      color: color,
      hoverColor: theme.primaryColor,
      iconSize: 18,
      padding: 8,
      isSelected: isSelected,
      scaleOnHover: 1.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      label: title, // Always pass label for smooth reveal transition
      showLabel: _isExtended,
      labelStyle: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );

    return button;
  }
}
