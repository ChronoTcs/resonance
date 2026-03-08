import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/library_provider.dart';
import '../../data/models/media_item.dart';
import '../../../player/data/repositories/audio_provider.dart';
import '../../../player/presentation/screens/video_player_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        .where((m) => m.type == 'audio')
        .toList();
    final videoList = libraryState.allMedia
        .where((m) => m.type == 'video')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Local Library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Music', icon: Icon(Icons.music_note)),
              Tab(text: 'Video', icon: Icon(Icons.movie)),
            ],
          ),
          actions: [
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
          leading: isAudio && item.albumArt != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    item.albumArt!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isAudio
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isAudio ? Icons.music_note : Icons.movie,
                    color: isAudio
                        ? Theme.of(context).primaryColor
                        : Colors.blueAccent,
                  ),
                ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            isAudio ? (item.artist ?? 'Unknown Artist') : item.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            if (isAudio) {
              ref.read(audioProvider.notifier).playTrack(item);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(videoItem: item),
                ),
              );
            }
          },
        );
      },
    );
  }
}
