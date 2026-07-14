import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import '../../application/library_provider.dart';
import '../../data/models/media_item.dart';
import '../../../player/application/services/queue_orchestrator.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/core/utils/uicons.dart';

import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(libraryProvider);

    final bool hasPaths = libraryState.musicFolderPath != null;
    
    // Define the main content based on state
    Widget content;

    if (!hasPaths) {
      content = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            'Library paths not configured.\nPlease go to Settings to add folders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    } else if (libraryState.isLoading && libraryState.allMedia.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (libraryState.allMedia.isEmpty && !libraryState.isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            'No media files found in the configured folders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    } else {
      final audioList = libraryState.allMedia
          .where((m) => m.type == 'audio' && 
              (m.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
               (m.artist?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)))
          .toList();

      content = TabBarView(
        controller: _tabController,
        children: [
          _buildMediaList(audioList, ref),
          const PlaylistScreen(isLocalOnly: true),
        ],
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          TopNavigationHeader(
            left: _isSearching
                ? Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search in library...',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          'Local Library',
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
                    ],
                  ),
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReusableHoverIconButton(
                  icon: _isSearching ? UIcons.regular.cross_small : UIcons.regular.search,
                  tooltip: _isSearching ? 'Close search' : 'Search library',
                  iconSize: 18,
                  onTap: () {
                    setState(() {
                      if (_isSearching) {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      } else {
                        _isSearching = true;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                ReusableHoverIconButton(
                  icon: libraryState.isLoading ? null : UIcons.regular.refresh,
                  tooltip: 'Scan folders',
                  iconSize: 18,
                  onTap: () {
                    if (_tabController.index == 0) {
                      ref.read(libraryProvider.notifier).scanLibrary();
                    }
                  },
                  child: libraryState.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaList(List<MediaItem> mediaList, WidgetRef ref) {
    if (mediaList.isEmpty) {
      return const Center(
        child: Text(
          'No items found in this category.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SilkyListView.builder(
      itemCount: mediaList.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final item = mediaList[index];

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index % 10 * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: ListTile(
          leading: MediaArtworkWidget(
            item: item,
            width: 48,
            height: 48,
            borderRadius: 4,
            placeholderIcon: UIcons.regular.music,
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.artist ?? 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: OverflowMenuButton(
            tooltip: 'More options',
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => MediaActionsBottomSheet(
                  item: item,
                  onDelete: () => _confirmDelete(context, ref, item),
                ),
              );
            },
          ),
          onTap: () {
            ref.read(queueOrchestratorProvider).playSequentialContext(item, mediaList);
          },
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => MediaActionsBottomSheet(
                item: item,
                onDelete: () => _confirmDelete(context, ref, item),
              ),
            );
          },
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Permanently delete "${item.title}" from your device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dlg);
              ref.read(libraryProvider.notifier).deleteTrack(item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${item.title}" deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
