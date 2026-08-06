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

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text('Add to Playlist', style: theme.textTheme.titleLarge),
                const Spacer(),
                ResonanceButton(
                  onPressed: _selectedIds.isEmpty ? null : () async {
                    final selectedTracks = libraryState.allMedia
                        .where((m) => _selectedIds.contains(m.id ?? m.path))
                        .toList();
                    await ref.read(playlistProvider.notifier).addTracksToPlaylist(widget.playlistId, selectedTracks);
                    if (context.mounted) Navigator.pop(context);
                  },
                  label: 'Add (${_selectedIds.length})',
                  style: ResonanceButtonStyle.primary,
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
              itemCount: music.length,
              itemBuilder: (context, index) {
                final track = music[index];
                final trackId = track.id ?? track.path;
                final isSelected = _selectedIds.contains(trackId);
                final alreadyInPlaylist = ref.read(playlistProvider.notifier).isTrackInPlaylist(widget.playlistId, track);

                return Material(
                  color: Colors.transparent,
                  child: Theme(
                    data: theme.copyWith(
                      checkboxTheme: CheckboxThemeData(
                        splashRadius: 18,
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                            return theme.colorScheme.onSurface.withValues(alpha: 0.08);
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return theme.colorScheme.onSurface.withValues(alpha: 0.16);
                          }
                          return null;
                        }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    child: CheckboxListTile(
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
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
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
