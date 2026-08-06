import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';

import 'package:resonance/features/home/presentation/providers/home_navigation_provider.dart';
import 'package:resonance/features/home/presentation/screens/components/recent_sub_page.dart';
import 'package:resonance/features/home/presentation/screens/components/playlist_sub_page.dart';
import 'package:resonance/features/home/presentation/screens/components/artist_sub_page.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Watch current provider state initially
    final initialTab = ref.read(homeNavigationProvider);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(homeNavigationProvider.notifier).setIndex(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPlaylistId = ref.watch(selectedHomePlaylistProvider);

    // Sync tab controller if state changes from elsewhere
    ref.listen<int>(homeNavigationProvider, (prev, next) {
      if (next != _tabController.index) {
        _tabController.animateTo(next);
      }
    });

    // If a playlist is selected inside the Home context, show its detail view
    if (selectedPlaylistId != null) {
      return Scaffold(
        body: Column(
          children: [
            TopNavigationHeader(
              left: Row(
                children: [
                  ReusableHoverIconButton(
                    icon: UIcons.regular.angle_small_left,
                    tooltip: 'Back to Home',
                    onTap: () => ref.read(selectedHomePlaylistProvider.notifier).setSelectedId(null),
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              right: const SizedBox(),
            ),
            Expanded(
              child: PlaylistDetailScreen(
                playlistId: selectedPlaylistId,
                showBackButton: false,
              ),
            ),
          ],
        ),
      );
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Column(
        children: [
          if (isDesktop) ...[
            TopNavigationHeader(
              left: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Home',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.label,
                        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return theme.primaryColor.withValues(alpha: 0.08);
                          }
                          return null;
                        }),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(UIcons.regular.clock, size: 14),
                                const SizedBox(width: 6),
                                const Text('Recent'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(UIcons.regular.list_music, size: 14),
                                const SizedBox(width: 6),
                                const Text('Playlists'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(UIcons.regular.user, size: 14),
                                const SizedBox(width: 6),
                                const Text('Artists'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              right: const SizedBox.shrink(),
            ),
          ] else ...[
            TopNavigationHeader(
              left: SizedBox(
                width: 140,
                child: Text(
                  'Home',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              right: const SizedBox.shrink(),
            ),
            Column(
              children: [
                Container(
                  height: 37,
                  color: theme.colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: 'Recent'),
                      Tab(text: 'Playlists'),
                      Tab(text: 'Artists'),
                    ],
                  ),
                ),
                GlossyAnimatedBackground(
                  isSelected: true,
                  borderRadius: BorderRadius.zero,
                  baseColor: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.primaryColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: const SizedBox(
                    height: 1,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                RecentSubPage(key: ValueKey('recent_tab')),
                PlaylistSubPage(key: ValueKey('playlist_tab')),
                ArtistSubPage(key: ValueKey('artist_tab')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
