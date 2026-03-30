import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import '../../application/library_provider.dart';
import '../../data/models/media_item.dart';
import '../../../player/application/audio_provider.dart';
import '../../../player/presentation/screens/dedicated_video_player.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../../core/widgets/media_artwork_widget.dart';
import '../../../player/presentation/screens/web_video_sniffer_screen.dart';
import '../../../player/application/video_player_notifier.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';
import 'package:resonance_app/features/playlist/presentation/screens/playlist_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

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
    final libraryState = ref.watch(libraryProvider);

    final bool hasPaths = libraryState.musicFolderPath != null || libraryState.videoFolderPath != null;
    
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
      final videoList = libraryState.allMedia
          .where((m) => m.type == 'video' && 
              (m.path.toLowerCase().contains(_searchQuery.toLowerCase()) || 
               m.title.toLowerCase().contains(_searchQuery.toLowerCase())))
          .toList();

      if (Platform.isAndroid) {
        content = TabBarView(
          controller: _tabController,
          children: [
            _buildMediaList(audioList, ref),
            const PlaylistScreen(),
          ],
        );
      } else {
        content = TabBarView(
          controller: _tabController,
          children: [
            _buildMediaList(audioList, ref),
            _buildVideoTab(videoList, ref),
          ],
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        primary: false,
        title: _isSearching
            ? TextField(
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
              )
            : const Text('Local Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: Platform.isAndroid
              ? const [
                  Tab(text: 'Local', icon: Icon(Icons.folder_open)),
                  Tab(text: 'Playlists', icon: Icon(Icons.queue_music)),
                ]
              : const [
                  Tab(text: 'Music', icon: Icon(Icons.music_note)),
                  Tab(text: 'Video', icon: Icon(Icons.movie)),
                ],
        ),
        actions: [
          ModernIconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
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
          Stack(
            children: [
              ModernIconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Scan folders',
                onPressed: () {
                  // Only scan if on Local Library tab (index 0)
                  if (_tabController.index == 0) {
                    ref.read(libraryProvider.notifier).scanLibrary();
                  } else {
                    // Maybe refresh playlist data? 
                    // playlistProvider is usually auto-refreshing but we can force it
                    // ref.invalidate(playlistProvider);
                  }
                },
              ),
              if (libraryState.isLoading)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: content,
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

    return ListView.builder(
      itemCount: mediaList.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final item = mediaList[index];
        final isAudio = item.type == 'audio';
        
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
          leading: (isAudio || item.thumbnailUrl != null)
              ? MediaArtworkWidget(
                  item: item,
                  width: 48,
                  height: 48,
                  borderRadius: 4,
                  placeholderIcon: isAudio ? Icons.music_note : Icons.movie,
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.movie,
                    color: Colors.blueAccent,
                  ),
                ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            isAudio ? (item.artist ?? 'Unknown Artist') : item.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ModernIconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onPressed: () {
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
            if (isAudio) {
              ref.read(audioProvider.notifier).playPlaylist(mediaList, initialIndex: index);
            } else {
              ref.read(videoPlayerProvider.notifier).playVideo(item);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DedicatedVideoPlayer(),
                ),
              );
            }
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

  Widget _buildVideoTab(List<MediaItem> videoList, WidgetRef ref) {
    return Column(
      children: [
        // Selection Options
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: _buildChoiceCard(
                  title: 'Local Videos',
                  icon: Icons.folder,
                  subtitle: '${videoList.length} files found',
                  onTap: () {
                    // Just stay in the list view
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildChoiceCard(
                  title: 'Online Video',
                  icon: Icons.public,
                  subtitle: 'Web Sniffer',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebVideoSnifferScreen(
                          initialUrl: 'https://www.google.com',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List restricted to Local Videos
        Expanded(child: _buildMediaList(videoList, ref)),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return HoverWrapper(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (color ?? Theme.of(context).primaryColor).withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
