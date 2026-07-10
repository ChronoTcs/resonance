import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/overflow_menu_button.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import '../../application/services/youtube_auth_service.dart';

import 'youtube_login_screen.dart';
import 'package:resonance/core/widgets/top_navigation_header.dart';
// import 'package:resonance/core/widgets/hover_widgets.dart'; // Unused

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchQueryProvider.notifier).setQuery(query);
      FocusScope.of(context).unfocus(); // Dismiss keyboard
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = ref.watch(searchStateProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final currentQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      body: Column(
        children: [
          TopNavigationHeader(
            left: Text(
              'Explore',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width > 600 ? 240 : 150,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: theme.textTheme.bodyMedium,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search songs online...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                      prefixIcon: Icon(AppIcons.search, size: 16, color: theme.hintColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? ReusableHoverIconButton(
                              icon: AppIcons.close,
                              tooltip: 'Clear search',
                              iconSize: 14,
                              onTap: () {
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).setQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 0, bottom: 4),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                _buildAuthButton(context, ref),
              ],
            ),
          ),
          Expanded(
            child: SilkyCustomScrollView(
              slivers: [

          // ─── Content Area ───────────────────────────────────────────────
          if (currentQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                         'Recently Played',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(recentlyPlayedProvider.notifier).clearHistory();
                      },
                      icon: Icon(AppIcons.trash, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildRecentPlays(ref, theme),
            const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
          ] else ...[
            if (isSearching)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              searchResultsAsync.when(
                data: (results) {
                  if (results.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text('No results found')),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = results[index];
                        Duration trackDuration = Duration.zero;
                        final parts = item.duration.split(':');
                        if (parts.length == 2) {
                          trackDuration = Duration(minutes: int.tryParse(parts[0]) ?? 0, seconds: int.tryParse(parts[1]) ?? 0);
                        } else if (parts.length == 3) {
                          trackDuration = Duration(hours: int.tryParse(parts[0]) ?? 0, minutes: int.tryParse(parts[1]) ?? 0, seconds: int.tryParse(parts[2]) ?? 0);
                        }

                        final mediaItem = MediaItem(
                          id: item.id,
                          path: item.id, // Gunakan ID sebagai path awal agar isStreaming terpicu
                          title: item.title,
                          artist: item.author,
                          thumbnailUrl: item.thumbnailUrl,
                          duration: trackDuration,
                          type: 'audio',
                        );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: item.thumbnailUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                child: Icon(AppIcons.music),
                              ),
                              errorWidget: (context, url, error) => Icon(UIcons.regular.exclamation),
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${item.author} • ${item.duration}'),
                          onTap: () {
                            ref.read(audioProvider.notifier).playYouTubeTrack(mediaItem);
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => MediaActionsBottomSheet(
                                item: mediaItem,
                                video: item.originalVideo,
                              ),
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              OverflowMenuButton(
                                tooltip: 'Actions',
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (_) => MediaActionsBottomSheet(
                                      item: mediaItem,
                                      video: item.originalVideo,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
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
              ),
          ],
        ],
      ),
    ),
  ],
),
    );
  }

  Widget _buildAuthButton(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(youtubeAuthServiceProvider);
    final isLoggedIn = authService.isLoggedIn;

    return ReusableHoverIconButton(
      icon: isLoggedIn ? UIcons.regular.user : UIcons.regular.enter,
      tooltip: isLoggedIn ? 'YouTube Account Active' : 'Login to YouTube',
      color: isLoggedIn ? Colors.redAccent : null,
      iconSize: 18,
      onTap: () async {
        if (isLoggedIn) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('YouTube Logout'),
              content: const Text('Are you sure you want to logout from YouTube?'),
              actions: [
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
                TextButton(
                  child: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await ref.read(youtubeAuthServiceProvider).logout();
            setState(() {});
          }
        } else {
          final success = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const YoutubeLoginScreen()),
          );
          if (success == true) setState(() {});
        }
      },
    );
  }

  Widget _buildRecentPlays(WidgetRef ref, ThemeData theme) {
    final recentAsync = ref.watch(recentlyPlayedProvider).whenData(
      (items) => items.where((item) => item.id != null && !item.isLocal).toList(),
    );
    
    return recentAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
                ),
                child: const Center(
                  child: Text('Play some online songs to see them here!', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ),
          );
        }
        
        return SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: MediaArtworkWidget(
                item: item,
                width: 52,
                height: 52,
                borderRadius: 8,
                placeholderIcon: AppIcons.music,
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.artist ?? 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                ref.read(audioProvider.notifier).playYouTubeTrack(item);
              },
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => MediaActionsBottomSheet(item: item),
                );
              },
              trailing: OverflowMenuButton(
                tooltip: 'Actions',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => MediaActionsBottomSheet(item: item),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: SizedBox(height: 140, child: Center(child: Text('Error: $e'))),
      ),
    );
  }
}
