import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:resonance_app/features/library/presentation/screens/library_screen.dart';
import 'package:resonance_app/features/player/presentation/widgets/mini_player.dart';
import 'package:resonance_app/features/lyrics/presentation/widgets/lyrics_screen.dart';
import 'package:resonance_app/features/lyrics/presentation/providers/lyrics_ui_provider.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _selectedIndex = 0;
  bool _isExtended = false;

  final List<Widget> _screens = [
    const Center(child: Text("Music Home", style: TextStyle(fontSize: 24))),
    const LibraryScreen(),
    const Center(child: Text("Playlists", style: TextStyle(fontSize: 24))),
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
                            child: ListView(
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
                                  'Library',
                                  Icons.library_music_outlined,
                                  Icons.library_music,
                                ),
                                _buildNavItem(
                                  2,
                                  'Playlists',
                                  Icons.queue_music_outlined,
                                  Icons.queue_music,
                                ),
                                _buildNavItem(
                                  3,
                                  'Settings',
                                  Icons.settings_outlined,
                                  Icons.settings,
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
                      : _screens[_selectedIndex],
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
              currentIndex: _selectedIndex,
              onTap: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
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
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    // In dark mode, primary is light. In light mode, primary is dark.
    final activeColor = theme.primaryColor;
    final inactiveColor = theme.iconTheme.color!.withOpacity(0.5);
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      hoverColor: Colors.white.withOpacity(0.05),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            // Active Indicator (Accent bar)
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Icon(
              isSelected ? selectedIconData : iconData,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 24),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}
