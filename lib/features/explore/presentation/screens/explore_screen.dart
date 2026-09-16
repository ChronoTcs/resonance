import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/search_history_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_music_tile.dart';
import 'package:resonance/features/explore/presentation/widgets/explore_playlist_card_tile.dart';
import 'package:resonance/features/explore/presentation/widgets/mood_genre_section.dart';
import 'package:resonance/features/explore/presentation/widgets/recent_searches_carousel_section.dart';
import 'package:resonance/features/explore/presentation/widgets/search_suggestions_section.dart';
import 'package:resonance/features/explore/presentation/widgets/mobile_search_history_section.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

/// Dedicated Explore & Discovery Screen for both Windows and Android.
///
/// Default Discovery View:
/// 1. Component 1: Recent Searches Horizontal Carousel (Picture 1 - "Penelusuran terbaru")
/// 2. Component 2: Search Suggestions List (Picture 2 - "Anda mungkin juga suka")
/// 3. Component 3: Moods & Genres 4-Row Pill Carousel (Picture 5 - "Jenis musik & suasana")
///
/// Live Search View:
/// - Instant filtered results for Music tracks and Playlists with TabBar switching.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _initTabController();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    final initialQuery = ref.read(searchQueryProvider);
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchController.selection = TextSelection.collapsed(offset: initialQuery.length);
      _isSearchOpen = true;
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
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
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.removeListener(_onSearchChanged);
    _tabController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    ref.read(searchQueryProvider.notifier).clear();
  }

  void _refreshExplore() {
    ref.invalidate(searchResultsProvider);
    ref.invalidate(searchPlaylistResultsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = AppBreakpoints.isCompact(context);
    final theme = Theme.of(context);
    final isSearching = ref.watch(searchStateProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final searchPlaylistsAsync = ref.watch(searchPlaylistResultsProvider);
    final currentQuery = ref.watch(searchQueryProvider);
    final activeTab = ref.watch(exploreSearchTabProvider);

    if (_tabController != null && _tabController!.index != activeTab) {
      _tabController!.animateTo(activeTab);
    }

    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (next != _searchController.text) {
        _searchController.text = next;
        _searchController.selection = TextSelection.collapsed(offset: next.length);
      }
      if (next.isNotEmpty && !_isSearchOpen) {
        setState(() {
          _isSearchOpen = true;
        });
      }
    });

    final hasQuery = currentQuery.isNotEmpty;
    if (hasQuery && !_isSearchOpen) {
      _isSearchOpen = true;
    }
    final showMobileSearch = isCompact && (_isSearchOpen || hasQuery);

    if (currentQuery.isEmpty && _searchController.text.isNotEmpty && !_isSearchOpen && !_searchFocusNode.hasFocus) {
      _searchController.clear();
    }

    return PopScope(
      canPop: !hasQuery && !_isSearchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
            return;
          }
          setState(() {
            _isSearchOpen = false;
            _searchController.clear();
          });
          if (hasQuery) {
            _clearSearch();
          }
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),

            // Top Navigation / Search Header
            if (!isCompact)
              TopNavigationHeader(
                left: hasQuery
                    ? _ExploreHeaderTabs(controller: _tabController)
                    : Text(
                        'Explore',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                actions: [
                  ReusableHoverIconButton(
                    icon: UIcons.regular.refresh,
                    tooltip: 'Refresh',
                    iconSize: 18,
                    onTap: _refreshExplore,
                  ),
                ],
              )
            else
              TopNavigationHeader(
                left: showMobileSearch
                    ? TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (query) {
                          final trimmed = query.trim();
                          if (trimmed.isNotEmpty) {
                            ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
                            ref.read(searchQueryProvider.notifier).setQuery(trimmed);
                          }
                          _searchFocusNode.unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search songs, artists, albums...',
                          border: InputBorder.none,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Center(
                                    child: ReusableHoverIconButton(
                                      icon: UIcons.regular.cross_small,
                                      tooltip: 'Clear text',
                                      iconSize: 16,
                                      padding: 2.0,
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        _searchController.clear();
                                        _clearSearch();
                                        setState(() {
                                          _isSearchOpen = true;
                                        });
                                        _searchFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      )
                    : Text(
                        'Explore',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                right: showMobileSearch
                    ? TextButton(
                        onPressed: () {
                          _searchFocusNode.unfocus();
                          setState(() {
                            _isSearchOpen = false;
                            _searchController.clear();
                          });
                          _clearSearch();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Cancel',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReusableHoverIconButton(
                            icon: UIcons.regular.search,
                            tooltip: 'Search',
                            iconSize: 18,
                            onTap: () {
                              setState(() {
                                _isSearchOpen = true;
                              });
                              _searchFocusNode.requestFocus();
                            },
                          ),
                          const SizedBox(width: 6),
                          ReusableHoverIconButton(
                            icon: UIcons.regular.refresh,
                            tooltip: 'Refresh',
                            iconSize: 18,
                            onTap: _refreshExplore,
                          ),
                        ],
                      ),
              ),

            // Mobile Filter Tabs when search query is active and not actively typing
            if (isCompact && hasQuery && !_searchFocusNode.hasFocus)
              ResonanceSegmentedBar(
                items: [
                  ResonanceSegmentItem(
                    label: 'Music',
                    icon: UIcons.regular.music,
                  ),
                  ResonanceSegmentItem(
                    label: 'Playlists',
                    icon: UIcons.regular.list_music,
                  ),
                ],
                selectedIndex: activeTab,
                onSelected: (index) {
                  ref.read(exploreSearchTabProvider.notifier).setTab(index);
                },
              ),

            // Body: Live Search Results vs Mobile Search History vs Discovery Feed
            Expanded(
              child: (isCompact && (_searchFocusNode.hasFocus || (_isSearchOpen && !hasQuery)))
                  ? MobileSearchHistorySection(
                      filterText: _searchController.text,
                      onSelect: (query) {
                        _searchFocusNode.unfocus();
                        _searchController.text = query;
                        _searchController.selection = TextSelection.collapsed(offset: query.length);
                        ref.read(searchHistoryProvider.notifier).addQuery(query);
                        ref.read(searchQueryProvider.notifier).setQuery(query);
                      },
                      onInsert: (query) {
                        _searchController.text = query;
                        _searchController.selection = TextSelection.collapsed(offset: query.length);
                        _searchFocusNode.requestFocus();
                        if (mounted) setState(() {});
                      },
                    )
                  : hasQuery
                      ? _ExploreSearchResultsView(
                          isSearching: isSearching,
                          activeTab: activeTab,
                          searchResultsAsync: searchResultsAsync,
                          searchPlaylistsAsync: searchPlaylistsAsync,
                        )
                      : _buildDiscoveryFeed(),
            ),
          ],
        ),
      ),
    );
  }

  /// Default Discovery Feed containing the 3 core components requested
  Widget _buildDiscoveryFeed() {
    return SilkyCustomScrollView(
      slivers: [
        // ── Component 1: Recent Searches Carousel (Picture 1) ─────────────────
        SliverToBoxAdapter(
          child: RecentSearchesCarouselSection(
            title: 'Recent searches',
            onTrackSelected: (item) {
              if (item.isLocal ||
                  (item.path.isNotEmpty && !item.isStreaming && !item.path.startsWith('http'))) {
                ref.read(audioProvider.notifier).playTrack(item);
              } else {
                ref.read(audioProvider.notifier).playYouTubeTrack(item);
              }
            },
          ),
        ),

        // ── Component 2: Search Suggestions List (Picture 2) ───────────────────
        SliverToBoxAdapter(
          child: SearchSuggestionsSection(
            title: 'You might also like',
            onSubmitQuery: (query) => ref.read(searchQueryProvider.notifier).setQuery(query),
            onInsertQuery: (query) => ref.read(searchQueryProvider.notifier).setQuery(query),
          ),
        ),

        // ── Component 3: Moods & Genres 4-Row Pill Carousel (Picture 5) ───────
        SliverToBoxAdapter(
          child: MoodGenreSection(
            title: 'Moods & genres',
            onCategorySelected: (category) {
              ref.read(searchQueryProvider.notifier).setQuery('$category music');
            },
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _ExploreHeaderTabs extends StatelessWidget {
  final TabController? controller;

  const _ExploreHeaderTabs({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TabBar(
        mouseCursor: SystemMouseCursors.click,
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(UIcons.regular.music, size: 14),
                const SizedBox(width: 8),
                const Text('Music'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(UIcons.regular.list_music, size: 14),
                const SizedBox(width: 8),
                const Text('Playlists'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _ExploreSearchResultsView extends StatelessWidget {
  final bool isSearching;
  final int activeTab;
  final AsyncValue<List<dynamic>> searchResultsAsync;
  final AsyncValue<List<dynamic>> searchPlaylistsAsync;

  const _ExploreSearchResultsView({
    required this.isSearching,
    required this.activeTab,
    required this.searchResultsAsync,
    required this.searchPlaylistsAsync,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      // Show a skeleton that matches the current tab's card design
      if (activeTab == 0) {
        return const SingleChildScrollView(child: ExploreMusicListSkeleton());
      } else {
        return const SingleChildScrollView(child: ExplorePlaylistCardListSkeleton());
      }
    }

    if (activeTab == 0) {
      return searchResultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return const Center(child: Text('No tracks found'));
          }
          return SilkyListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) =>
                ExploreMusicTile(item: results[index]),
          );
        },
        loading: () => const SingleChildScrollView(child: ExploreMusicListSkeleton()),
        error: (err, _) => Center(child: Text('Error: $err')),
      );
    } else {
      return searchPlaylistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(child: Text('No playlists found'));
          }
          return SilkyListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: playlists.length,
            itemBuilder: (context, index) =>
                ExplorePlaylistCardTile(playlist: playlists[index]),
          );
        },
        loading: () => const SingleChildScrollView(child: ExplorePlaylistCardListSkeleton()),
        error: (err, _) => Center(child: Text('Error: $err')),
      );
    }
  }
}
