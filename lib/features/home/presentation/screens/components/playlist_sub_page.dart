import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/home/presentation/providers/home_navigation_provider.dart';

class PlaylistSubPage extends ConsumerWidget {
  const PlaylistSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final theme = Theme.of(context);

    return playlistsAsync.when(
      data: (state) {
        final allPlaylists = [...state.local, ...state.online];
        if (allPlaylists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.playlist,
                  size: 64,
                  color: theme.disabledColor,
                ),
                const SizedBox(height: 16),
                const Text('No playlists found'),
              ],
            ),
          );
        }

        return SilkyListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          itemCount: allPlaylists.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final playlist = allPlaylists[index];
            final bool isOnline = state.online.contains(playlist);
            final firstTrack = playlist.tracks.isNotEmpty ? playlist.tracks.first : null;

            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  ref.read(selectedHomePlaylistProvider.notifier).setSelectedId(playlist.id);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: firstTrack?.albumArt != null
                            ? Image.memory(
                                firstTrack!.albumArt!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : (firstTrack?.thumbnailUrl != null)
                                ? CachedNetworkImage(
                                    imageUrl: firstTrack!.thumbnailUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) => Container(color: theme.colorScheme.surfaceContainerHighest, child: Icon(AppIcons.music, size: 20)),
                                    errorWidget: (c, u, e) => Container(color: theme.colorScheme.surfaceContainerHighest, child: Icon(AppIcons.music, size: 20)),
                                  )
                                : Container(
                                    width: 56,
                                    height: 56,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      AppIcons.playlist,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${playlist.tracks.length} track${playlist.tracks.length == 1 ? "" : "s"} • ${isOnline ? "Online" : "Local"}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
}
