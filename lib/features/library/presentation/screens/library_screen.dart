import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/library_provider.dart';
import '../../data/models/media_item.dart';
import '../../../player/application/services/queue_orchestrator.dart';
import '../../../player/presentation/screens/dedicated_video_player.dart';
import '../../../../core/widgets/media_actions_bottom_sheet.dart';
import '../../../../core/widgets/media_artwork_widget.dart';
import '../../../player/presentation/screens/web_video_sniffer_screen.dart';
import '../../../player/application/providers/video_player_notifier.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance_app/core/widgets/overflow_menu_button.dart';
import 'package:resonance_app/features/playlist/presentation/screens/playlist_screen.dart';

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
      resizeToAvoidBottomInset: false,
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
              ? [
                  Tab(text: 'Local', icon: Icon(UIcons.regular.folder_open, size: 18)),
                  Tab(text: 'Playlists', icon: Icon(UIcons.regular.list_music, size: 18)),
                ]
              : [
                  Tab(text: 'Music', icon: Icon(UIcons.regular.music, size: 18)),
                  Tab(text: 'Video', icon: Icon(UIcons.regular.video_camera, size: 18)),
                ],
        ),
        actions: [
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
          ReusableHoverIconButton(
            icon: libraryState.isLoading ? null : UIcons.regular.refresh,
            tooltip: 'Scan folders',
            iconSize: 18,
            onTap: () {
              // Only scan if on Local Library tab (index 0)
              if (_tabController.index == 0) {
                ref.read(libraryProvider.notifier).scanLibrary();
              }
            },
            child: libraryState.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : null,
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
                  placeholderIcon: isAudio ? UIcons.regular.music : UIcons.regular.video_camera,
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    UIcons.regular.video_camera,
                    color: Colors.blueAccent,
                  ),
                ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            isAudio ? (item.artist ?? 'Unknown Artist') : item.path,
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
            if (isAudio) {
              ref.read(queueOrchestratorProvider).playSequentialContext(item, mediaList);
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
                  icon: UIcons.regular.folder,
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
                  icon: UIcons.regular.globe,
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
    return ReusableHoverIconButton(
      onTap: onTap,
      tooltip: title,
      padding: 0,
      scaleOnHover: 1.05,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (color ?? Theme.of(context).primaryColor).withValues(alpha: 0.2),
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
