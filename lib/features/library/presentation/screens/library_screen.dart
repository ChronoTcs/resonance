import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/playlist/data/models/playlist_model.dart';
import '../../data/repositories/library_provider.dart';
import '../../data/models/media_item.dart';
import '../../../player/data/repositories/audio_provider.dart';
import '../../../player/presentation/screens/video_player_screen.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../../core/widgets/media_artwork_widget.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);

    if (libraryState.musicFolderPath == null &&
        libraryState.videoFolderPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Local Library')),
        body: const Center(
          child: Text(
            'Library paths not configured.\nPlease go to Settings to add folders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    if (libraryState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Local Library')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (libraryState.allMedia.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Local Library'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(libraryProvider.notifier).scanLibrary();
              },
            ),
          ],
        ),
        body: const Center(
          child: Text(
            'No media files found in the configured folders.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Music', icon: Icon(Icons.music_note)),
              Tab(text: 'Video', icon: Icon(Icons.movie)),
            ],
          ),
          actions: [
            IconButton(
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
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(libraryProvider.notifier).scanLibrary();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Music Tab
            _buildMediaList(audioList, ref),
            // Video Tab
            _buildMediaList(videoList, ref),
          ],
        ),
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

    return ListView.builder(
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final item = mediaList[index];
        final isAudio = item.type == 'audio';
        return ListTile(
          leading: isAudio
              ? MediaArtworkWidget(
                  item: item,
                  width: 48,
                  height: 48,
                  borderRadius: 4,
                  placeholderIcon: Icons.music_note,
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
          trailing: IconButton(
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(videoItem: item),
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
              ref.read(libraryProvider.notifier).deleteTrack(item.path);
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
