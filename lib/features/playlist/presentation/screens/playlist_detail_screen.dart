import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/core/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/app_back_button.dart';
import 'package:resonance/core/widgets/online_track_badge.dart';
import 'package:resonance/features/playlist/application/playlist_io_helper.dart';
import 'package:resonance/core/widgets/resonance_context_menu.dart';
import 'package:resonance/core/utils/app_icons.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: playlistsAsync.when(
        data: (state) {
          final allPlaylists = [...state.local, ...state.online];
          final playlist = allPlaylists
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

          return SilkyCustomScrollView(
            slivers: [
              // Hero AppBar with art background
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                elevation: 0,
                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
                leading: Center(
                  child: AppBackButton(
                    color: theme.colorScheme.onSurface,
                    onTap: () => ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(null),
                  ),
                ),
                actions: [
                  ReusableHoverIconButton(
                    icon: UIcons.regular.refresh,
                    tooltip: 'Repair Playlist',
                    iconSize: 18,
                    onTap: () async {
                      final libraryItems = ref.read(libraryProvider).allMedia;
                      final count = await ref
                          .read(playlistProvider.notifier)
                          .repairPlaylist(playlistId, libraryItems);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(count > 0 
                              ? 'Repaired $count broken tracks!' 
                              : 'No broken tracks found or no matches in library.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  ReusableHoverIconButton(
                    icon: UIcons.regular.add,
                    tooltip: 'Add Music',
                    iconSize: 18,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (ctx) => _MusicPickerSheet(playlistId: playlistId),
                      );
                    },
                  ),
                  if (state.online.any((p) => p.id == playlist.id))
                    ResonanceContextMenu(
                      items: PlaylistIOHelper.buildPlaylistMenuItems(
                        context: context,
                        ref: ref,
                        playlist: playlist,
                        isOnline: true,
                        onDeleteSuccess: () => ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(null),
                      ),
                      child: ReusableHoverIconButton(
                        icon: AppIcons.moreVert,
                        tooltip: 'More options',
                        iconSize: 18,
                      ),
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
                              color: theme.colorScheme.shadow.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                      titlePadding: const EdgeInsets.only(left: 48, bottom: 16),
                      background: firstTrack != null
                          ? ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.4),
                                BlendMode.darken,
                              ),
                              child: MediaArtworkWidget(
                                item: firstTrack,
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 0,
                                placeholderIcon: UIcons.regular.list_music,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.primary.withValues(alpha: 0.8),
                                    theme.colorScheme.tertiary.withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                              child: Icon(
                                UIcons.regular.list_music,
                                size: 100,
                                color: Colors.white.withValues(alpha: 0.3),
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
                        ReusableHoverIconButton(
                          icon: UIcons.regular.play,
                          tooltip: 'Play all tracks',
                          iconSize: 22,
                          onTap: () {
                            ref
                                .read(audioProvider.notifier)
                                .playPlaylist(tracks, initialIndex: 0);
                          },
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
                    final isOnline = track.isStreaming;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MediaArtworkWidget(
                            item: track,
                            width: 48,
                            height: 48,
                            borderRadius: 6,
                            placeholderIcon: isOnline ? UIcons.regular.globe : UIcons.regular.music,
                          ),
                          if (isOnline)
                            const Positioned(
                              top: -4,
                              left: -4,
                              child: OnlineTrackBadge(),
                            ),
                        ],
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
                      trailing: ReusableHoverIconButton(
                        icon: UIcons.regular.minus,
                        tooltip: 'Remove from playlist',
                        iconSize: 16,
                        padding: 4,
                        onTap: () {
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
