import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/providers/search_history_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/home/presentation/providers/home_navigation_provider.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/features/home/presentation/widgets/adaptive_home_header.dart';
import 'package:resonance/features/home/presentation/widgets/unified_home_feed.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_detail_screen.dart';

/// Unified responsive Home screen across all platforms and window sizes.
///
/// Combines local and streaming recommendations into the shared YouTube Music layout:
/// - Speed Dial 2-row bento grid
/// - Recently Played
/// - Local Quick Picks & Cached Streams
/// - Quick Picks 4-row column snap carousel
/// - Daily Discover & Forgotten Favorites
/// - Similar Artists
/// - Global Charts & Trending mixes
///
/// Responsively integrates:
/// - Adaptive Home Header (inline search on compact viewports routing to Explore tab;
///   title with global desktop search bar and actions on wide displays).
/// - Preserves playlist detail view navigation via [selectedHomePlaylistProvider].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFieldOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(homeFeedProvider);
    ref.invalidate(speedDialProvider);
    ref.invalidate(quickPicksProvider);
    ref.invalidate(dailyDiscoverProvider);
    ref.invalidate(forgottenFavoritesProvider);
    ref.invalidate(similarArtistsProvider);
    ref.invalidate(recentlyPlayedProvider);
    ref.read(libraryProvider.notifier).scanLibrary();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
    ref.read(searchQueryProvider.notifier).setQuery(trimmed);
    ref.read(mainNavigationProvider.notifier).setIndex(1);
    setState(() {
      _isSearchFieldOpen = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = AppBreakpoints.isCompact(context);
    final selectedPlaylistId = ref.watch(selectedHomePlaylistProvider);

    // If a playlist is selected inside the Home context, show its detail view
    if (selectedPlaylistId != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ref.read(selectedHomePlaylistProvider.notifier).setSelectedId(null);
          }
        },
        child: Scaffold(
          body: Column(
            children: [
              TopNavigationHeader(
                left: Row(
                  children: [
                    ReusableHoverIconButton(
                      icon: UIcons.regular.angle_small_left,
                      tooltip: 'Back to Home',
                      onTap: () => ref
                          .read(selectedHomePlaylistProvider.notifier)
                          .setSelectedId(null),
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
        ),
      );
    }

    return PopScope(
      canPop: !_isSearchFieldOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSearchFieldOpen) {
          setState(() {
            _isSearchFieldOpen = false;
            _searchController.clear();
          });
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            AdaptiveHomeHeader(
              isCompact: isCompact,
              isSearchFieldOpen: _isSearchFieldOpen,
              searchController: _searchController,
              onSubmitSearch: _submitSearch,
              onToggleSearch: () {
                setState(() {
                  if (_isSearchFieldOpen) {
                    _isSearchFieldOpen = false;
                    _searchController.clear();
                  } else {
                    _isSearchFieldOpen = true;
                  }
                });
              },
              onRefresh: _refreshAll,
            ),
            const Expanded(
              child: UnifiedHomeFeed(),
            ),
          ],
        ),
      ),
    );
  }
}

