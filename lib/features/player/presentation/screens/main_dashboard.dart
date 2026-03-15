import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/home/presentation/screens/home_screen.dart';
import 'package:resonance_app/features/download/presentation/screens/download_screen.dart';
import 'package:resonance_app/features/playlist/presentation/screens/playlist_screen.dart';
import 'package:resonance_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance_app/features/library/presentation/screens/library_screen.dart';
import 'package:resonance_app/features/player/presentation/widgets/mini_player.dart';
import 'package:resonance_app/features/lyrics/presentation/widgets/lyrics_screen.dart';
import 'package:resonance_app/features/lyrics/presentation/providers/lyrics_ui_provider.dart';
import 'package:resonance_app/core/providers/navigation_provider.dart';
import 'package:resonance_app/features/explore/presentation/screens/explore_screen.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  bool _isExtended = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const LibraryScreen(),
    const PlaylistScreen(),
    const DownloadScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Check if device is a large screen (Desktop/Tablet)
    final bool isDesktop = MediaQuery.of(context).size.width > 600;
    final bool showLyrics = ref.watch(lyricsOverlayProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  if (isDesktop)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isExtended ? 200 : 72,
                      color:
                          Theme.of(
                            context,
                          ).navigationRailTheme.backgroundColor ??
                          Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hamburger Menu
                          Container(
                            height: 72,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 12),
                            child: IconButton(
                              icon: const Icon(Icons.menu),
                              tooltip: _isExtended
                                  ? 'Close Navigation'
                                  : 'Open Navigation',
                              onPressed: () {
                                setState(() {
                                  _isExtended = !_isExtended;
                                });
                              },
                            ),
                          ),
                          // Navigation Items
                          Expanded(
                            child: Stack(
                              children: [
                                // Floating Active Indicator
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack, // Gives a slight bounce effect
                                  tween: Tween<double>(
                                    begin: ref.watch(mainNavigationProvider) * 56.0,
                                    end: ref.watch(mainNavigationProvider) * 56.0,
                                  ),
                                  builder: (context, value, child) {
                                    return Positioned(
                                      top: value,
                                      left: 0,
                                      child: Container(
                                        width: 4,
                                        height: 56,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        margin: const EdgeInsets.only(left: 8), // Aligns perfectly to the left edge of the padded hover box
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
                                ListView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildNavItem(
                                      0,
                                      'Home',
                                      Icons.home_outlined,
                                      Icons.home,
                                    ),
                                    _buildNavItem(
                                      1,
                                      'Explore',
                                      Icons.explore_outlined,
                                      Icons.explore,
                                    ),
                                    _buildNavItem(
                                      2,
                                      'Library',
                                      Icons.library_music_outlined,
                                      Icons.library_music,
                                    ),
                                    _buildNavItem(
                                      3,
                                      'Playlists',
                                      Icons.queue_music_outlined,
                                      Icons.queue_music,
                                    ),
                                    _buildNavItem(
                                      4,
                                      'Download',
                                      Icons.download_outlined,
                                      Icons.download_rounded,
                                    ),
                                    _buildNavItem(
                                      5,
                                      'Settings',
                                      Icons.settings_outlined,
                                      Icons.settings,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
                // Main Content
                Expanded(
                  child: showLyrics
                      ? const LyricsScreen(isEmbedded: true)
                      : _screens[ref.watch(mainNavigationProvider)],
                ),
              ],
            ),
          ),
          // Persist the Mini Player at the bottom of the body
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: ref.watch(mainNavigationProvider),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Theme.of(context).iconTheme.color?.withOpacity(0.5),
              onTap: (int index) {
                ref.read(mainNavigationProvider.notifier).setIndex(index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_music_outlined),
                  activeIcon: Icon(Icons.library_music),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.queue_music_outlined),
                  activeIcon: Icon(Icons.queue_music),
                  label: 'Playlists',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.download_outlined),
                  activeIcon: Icon(Icons.download_rounded),
                  label: 'Download',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
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
    final inactiveColor = theme.iconTheme.color!.withOpacity(0.5);
    final color = isSelected ? activeColor : inactiveColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ref.read(mainNavigationProvider.notifier).setIndex(index);
            },
            hoverColor: Colors.white.withOpacity(0.08),
            splashColor: Colors.white.withOpacity(0.12),
            highlightColor: Colors.white.withOpacity(0.05),
            child: SizedBox(
              height: 48, // Adjusted height for better padded look
              child: Row(
                children: [
                  // Re-add leading spacing to align icons perfectly in the 56px bounds (16 left + 24 icon + 16 right)
                  const SizedBox(width: 16),
                  Icon(
                    isSelected ? selectedIconData : iconData,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(width: 12), // Spacing between icon and text
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isExtended ? 1.0 : 0.0,
                      child: Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
