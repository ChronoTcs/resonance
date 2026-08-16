import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_music_tile.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_playlist_card_tile.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_recent_plays_section.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_home_feed_section.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    final activeTab = ref.read(exploreSearchTabProvider);
    _tabController = TabController(length: 2, vsync: this, initialIndex: activeTab);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        ref.read(exploreSearchTabProvider.notifier).setTab(_tabController!.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = ref.watch(searchStateProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final searchPlaylistsAsync = ref.watch(searchPlaylistResultsProvider);
    final currentQuery = ref.watch(searchQueryProvider);
    final activeTab = ref.watch(exploreSearchTabProvider);

    if (_tabController != null && _tabController!.index != activeTab) {
      _tabController!.animateTo(activeTab);
    }

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          TopNavigationHeader(
            left: currentQuery.isEmpty
                ? Text(
                    'Explore',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : SizedBox(
                    height: 50,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
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
                              Icon(UIcons.regular.music, size: 14),
                              const SizedBox(width: 6),
                              const Text('Music'),
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
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: SilkyCustomScrollView(
              slivers: [
                if (currentQuery.isEmpty) ...[
                  const ExploreRecentPlaysSection(),
                  const ExploreHomeFeedSection(),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ] else ...[
                  if (isSearching)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (activeTab == 0)
                    searchResultsAsync.when(
                      data: (results) {
                        if (results.isEmpty) {
                          return const SliverFillRemaining(
                            child: Center(child: Text('No results found')),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ExploreMusicTile(item: results[index]),
                            childCount: results.length,
                          ),
                        );
                      },
                      loading: () => const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, stack) => SliverFillRemaining(
                        child: Center(child: Text('Error: $err')),
                      ),
                    )
                  else
                    searchPlaylistsAsync.when(
                      data: (playlists) {
                        if (playlists.isEmpty) {
                          return const SliverFillRemaining(
                            child: Center(child: Text('No playlists found')),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => ExplorePlaylistCardTile(playlist: playlists[index]),
                              childCount: playlists.length,
                            ),
                          ),
                        );
                      },
                      loading: () => const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, stack) => SliverFillRemaining(
                        child: Center(child: Text('Error: $err')),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
