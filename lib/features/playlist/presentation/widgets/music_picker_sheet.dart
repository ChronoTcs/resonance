import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';

import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

class MusicPickerSheet extends ConsumerStatefulWidget {
  final String playlistId;
  const MusicPickerSheet({super.key, required this.playlistId});

  @override
  ConsumerState<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends ConsumerState<MusicPickerSheet> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    
    final playlistsAsync = ref.watch(playlistProvider);
    final playlistStateObj = playlistsAsync.value;
    final isStreamPlaylist = playlistStateObj != null &&
        playlistStateObj.online.any((p) => p.id == widget.playlistId);

    // Only show music for adding to playlists (filtering stream vs local tracks)
    final music = libraryState.allMedia
        .where((m) => m.type == 'audio' &&
            (isStreamPlaylist ? m.isStreaming : m.isLocal) &&
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
                      if (context.mounted) Navigator.pop(context);
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
                  prefixIcon: Icon(UIcons.regular.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              child: SilkyListView.builder(
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
