import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/player/data/repositories/audio_provider.dart';
import 'package:resonance_app/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:resonance_app/features/library/data/repositories/library_provider.dart';
import 'package:resonance_app/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance_app/core/widgets/media_artwork_widget.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: playlistsAsync.when(
        data: (playlists) {
          final playlist = playlists
              .where((p) => p.id == playlistId)
              .firstOrNull;
          if (playlist == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Playlist not found')),
            );
          }

          final tracks = playlist.tracks;
          final firstTrack = tracks.isNotEmpty ? tracks.first : null;

          return CustomScrollView(
            slivers: [
              // Hero AppBar with art background
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                elevation: 0,
                backgroundColor: theme.colorScheme.surface.withOpacity(0.7),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add Music',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (ctx) => _MusicPickerSheet(playlistId: playlistId),
                      );
                    },
                  ),
                ],
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: FlexibleSpaceBar(
                      title: Text(
                        playlist.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: theme.colorScheme.shadow.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      titlePadding: const EdgeInsets.only(left: 48, bottom: 16),
                      background: firstTrack != null
                          ? ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.4),
                                BlendMode.darken,
                              ),
                              child: MediaArtworkWidget(
                                item: firstTrack,
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 0,
                                placeholderIcon: Icons.queue_music_rounded,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.primary.withOpacity(0.8),
                                    theme.colorScheme.secondary.withOpacity(0.6),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                size: 100,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              // Track count + Play All button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tracks.length} track${tracks.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                      if (tracks.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () {
                            ref.read(audioProvider.notifier).playPlaylist(tracks, initialIndex: 0);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                        ),
                    ],
                  ),
                ),
              ),
              if (tracks.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'This playlist is empty.\nAdd songs from your library or explore.',
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (ctx, i) {
                    final track = tracks[i];
                    final isOnline = track.id != null;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: MediaArtworkWidget(
                        item: track,
                        width: 48,
                        height: 48,
                        borderRadius: 6,
                        placeholderIcon: isOnline ? Icons.public : Icons.music_note,
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        ref.read(audioProvider.notifier).playPlaylist(tracks, initialIndex: i);
                      },
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => MediaActionsBottomSheet(item: track),
                        );
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Remove from playlist',
                        onPressed: () {
                          ref
                              .read(playlistProvider.notifier)
                              .removeTrackFromPlaylist(playlistId, track.id ?? track.path);
                        },
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _MusicPickerSheet extends ConsumerStatefulWidget {
  final String playlistId;
  const _MusicPickerSheet({required this.playlistId});

  @override
  ConsumerState<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends ConsumerState<_MusicPickerSheet> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    
    // Only show music for adding to playlists
    final music = libraryState.allMedia
        .where((m) => m.type == 'audio' && 
            (m.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
             (m.artist?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text('Add to Playlist', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectedIds.isEmpty ? null : () async {
                      final selectedTracks = libraryState.allMedia
                          .where((m) => _selectedIds.contains(m.id ?? m.path))
                          .toList();
                      await ref.read(playlistProvider.notifier).addTracksToPlaylist(widget.playlistId, selectedTracks);
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text('Add (${_selectedIds.length})'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search my music...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: music.length,
                itemBuilder: (context, index) {
                  final track = music[index];
                  final trackId = track.id ?? track.path;
                  final isSelected = _selectedIds.contains(trackId);
                  final alreadyInPlaylist = ref.read(playlistProvider.notifier).isTrackInPlaylist(widget.playlistId, track);

                  return CheckboxListTile(
                    value: isSelected || alreadyInPlaylist,
                    onChanged: alreadyInPlaylist ? null : (v) {
                      setState(() {
                        if (v == true) {
                          _selectedIds.add(trackId);
                        } else {
                          _selectedIds.remove(trackId);
                        }
                      });
                    },
                    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(track.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis),
                    secondary: MediaArtworkWidget(
                      item: track,
                      width: 40,
                      height: 40,
                      borderRadius: 4,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
