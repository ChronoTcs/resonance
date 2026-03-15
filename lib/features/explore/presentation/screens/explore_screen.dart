import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance_app/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance_app/features/player/data/repositories/audio_provider.dart';
import 'package:resonance_app/features/library/data/models/media_item.dart';
import 'package:resonance_app/features/home/presentation/providers/recently_played_provider.dart';
import 'package:resonance_app/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';

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
      body: CustomScrollView(
        slivers: [
          // ─── Search Bar App Bar ──────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: true,
            title: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search songs online...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).setQuery('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
            ),
          ),

          // ─── Content Area ───────────────────────────────────────────────
          if (currentQuery.isEmpty) ...[
            // Default view when no search is active
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recently Played (Online)',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentPlays(ref, theme),
                    const SizedBox(height: 32),
                    Text(
                      'Featured Playlists',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildPlaylistsPlaceholder(theme),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Search Results view
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
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
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
                            final ytService = ref.read(youtubeServiceProvider);
                            
                            // Parse duration
                            Duration trackDuration = Duration.zero;
                            final parts = item.duration.split(':');
                            if (parts.length == 2) {
                              trackDuration = Duration(minutes: int.tryParse(parts[0]) ?? 0, seconds: int.tryParse(parts[1]) ?? 0);
                            } else if (parts.length == 3) {
                              trackDuration = Duration(hours: int.tryParse(parts[0]) ?? 0, minutes: int.tryParse(parts[1]) ?? 0, seconds: int.tryParse(parts[2]) ?? 0);
                            }

                            final mediaItem = MediaItem(
                              id: item.id,
                              path: item.thumbnailUrl, // temporary store thumbnail URL here to fetch in background
                              title: item.title,
                              artist: item.author,
                              thumbnailUrl: item.thumbnailUrl,
                              duration: trackDuration,
                              type: 'audio',
                            );

                            ref.read(audioProvider.notifier).playOnlineTrack(
                              mediaItem,
                              () => ytService.getAudioStreamUrl(item.id),
                            );
                          },
                          onLongPress: () {
                            // Re-wrap the search result into MediaItem for the bottom sheet
                            Duration trackDuration = Duration.zero;
                            final parts = item.duration.split(':');
                            if (parts.length == 2) {
                              trackDuration = Duration(minutes: int.tryParse(parts[0]) ?? 0, seconds: int.tryParse(parts[1]) ?? 0);
                            } else if (parts.length == 3) {
                              trackDuration = Duration(hours: int.tryParse(parts[0]) ?? 0, minutes: int.tryParse(parts[1]) ?? 0, seconds: int.tryParse(parts[2]) ?? 0);
                            }

                            final mediaItem = MediaItem(
                              id: item.id,
                              path: item.thumbnailUrl,
                              title: item.title,
                              artist: item.author,
                              thumbnailUrl: item.thumbnailUrl,
                              duration: trackDuration,
                              type: 'audio',
                            );

                            showModalBottomSheet(
                              context: context,
                              builder: (_) => MediaActionsBottomSheet(item: mediaItem),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              // Re-wrap the search result into MediaItem for the bottom sheet
                              Duration trackDuration = Duration.zero;
                              final parts = item.duration.split(':');
                              if (parts.length == 2) {
                                trackDuration = Duration(minutes: int.tryParse(parts[0]) ?? 0, seconds: int.tryParse(parts[1]) ?? 0);
                              } else if (parts.length == 3) {
                                trackDuration = Duration(hours: int.tryParse(parts[0]) ?? 0, minutes: int.tryParse(parts[1]) ?? 0, seconds: int.tryParse(parts[2]) ?? 0);
                              }

                              final mediaItem = MediaItem(
                                id: item.id,
                                path: item.thumbnailUrl,
                                title: item.title,
                                artist: item.author,
                                thumbnailUrl: item.thumbnailUrl,
                                duration: trackDuration,
                                type: 'audio',
                              );

                              showModalBottomSheet(
                                context: context,
                                builder: (_) => MediaActionsBottomSheet(item: mediaItem),
                              );
                            },
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
    );
  }

  Widget _buildRecentPlays(WidgetRef ref, ThemeData theme) {
    final recentAsync = ref.watch(recentlyPlayedProvider).whenData(
      (items) => items.where((item) => item.id != null).toList(),
    );
    
    return recentAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: const Center(
              child: Text('Play some songs to see them here!', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        if (item.id != null) {
                           final ytService = ref.read(youtubeServiceProvider);
                           ref.read(audioProvider.notifier).playOnlineTrack(
                             item,
                             () => ytService.getAudioStreamUrl(item.id!),
                           );
                        } else {
                           ref.read(audioProvider.notifier).playTrack(item);
                        }
                      },
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => MediaActionsBottomSheet(item: item),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            MediaArtworkWidget(
                              item: item,
                              width: 120,
                              height: 100,
                              borderRadius: 12,
                              placeholderIcon: Icons.album,
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  item.id != null ? Icons.public : Icons.folder,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      item.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 140, child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildPlaylistsPlaceholder(ThemeData theme) {
    return Consumer(
      builder: (context, ref, _) {
        final featuredAsync = ref.watch(featuredPlaylistsProvider);
        
        return featuredAsync.when(
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0, 
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () {
                    final ytService = ref.read(youtubeServiceProvider);
                    final mediaItem = MediaItem(
                      id: item.id,
                      path: item.thumbnailUrl,
                      title: item.title,
                      artist: item.author,
                      thumbnailUrl: item.thumbnailUrl,
                      duration: const Duration(minutes: 3), // placeholder or parse from item
                      type: 'audio',
                    );
                    ref.read(audioProvider.notifier).playOnlineTrack(
                      mediaItem,
                      () => ytService.getAudioStreamUrl(item.id),
                    );
                  },
                  onLongPress: () {
                    final mediaItem = MediaItem(
                      id: item.id,
                      path: item.thumbnailUrl,
                      title: item.title,
                      artist: item.author,
                      thumbnailUrl: item.thumbnailUrl,
                      duration: const Duration(minutes: 3),
                      type: 'audio',
                    );
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => MediaActionsBottomSheet(item: mediaItem),
                    );
                   },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: Colors.grey[900]),
                          errorWidget: (c, u, e) => const Icon(Icons.error),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.play_circle_filled, color: Colors.white70, size: 28),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      }
    );
  }
}
