import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/data/models/explore_playlist.dart';
import 'package:resonance/features/explore/presentation/providers/explore_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Detailed view for an online YouTube/community playlist selected from Explore search.
class OnlinePlaylistDetailScreen extends ConsumerWidget {
  final ExplorePlaylist playlist;

  const OnlinePlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tracksAsync = ref.watch(onlinePlaylistTracksProvider(playlist.id));

    final playlistMediaItem = MediaItem(
      id: playlist.id,
      title: playlist.title,
      artist: playlist.author,
      thumbnailUrl: playlist.thumbnailUrl,
      path: playlist.id,
      type: 'playlist',
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: tracksAsync.when(
              data: (tracks) => SilkyCustomScrollView(
                slivers: [
                  _OnlinePlaylistHeroAppBar(
                    playlist: playlist,
                    playlistMediaItem: playlistMediaItem,
                    onBackPressed: () => ref
                        .read(selectedExplorePlaylistProvider.notifier)
                        .setSelected(null),
                  ),
                  SliverToBoxAdapter(
                    child: _OnlinePlaylistHeaderActionsBar(
                      trackCount: tracks.length,
                      author: playlist.author,
                      onPlayAll: tracks.isNotEmpty
                          ? () => ref.read(audioProvider.notifier).playPlaylist(
                                tracks,
                                initialIndex: 0,
                                playlistId: playlist.id,
                              )
                          : null,
                      onSaveToPlaylists: () => MediaActionUtils.saveOnlinePlaylist(
                        context,
                        ref,
                        playlistMediaItem,
                      ),
                      onAddToQueue: tracks.isNotEmpty
                          ? () => MediaActionUtils.addOnlinePlaylistToQueue(
                                context,
                                ref,
                                playlistMediaItem,
                              )
                          : null,
                    ),
                  ),
                  if (tracks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              UIcons.regular.list_music,
                              size: 44,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.35),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tracks found in playlist',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: tracks.length,
                      itemBuilder: (ctx, i) {
                        final track = tracks[i];
                        return _OnlinePlaylistTrackTile(
                          track: track,
                          index: i,
                          onTap: () => ref
                              .read(audioProvider.notifier)
                              .playPlaylist(
                                tracks,
                                initialIndex: i,
                                playlistId: playlist.id,
                              ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
              loading: () => SilkyCustomScrollView(
                slivers: [
                  _OnlinePlaylistHeroAppBar(
                    playlist: playlist,
                    playlistMediaItem: playlistMediaItem,
                    onBackPressed: () => ref
                        .read(selectedExplorePlaylistProvider.notifier)
                        .setSelected(null),
                  ),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
              ),
              error: (err, _) => SilkyCustomScrollView(
                slivers: [
                  _OnlinePlaylistHeroAppBar(
                    playlist: playlist,
                    playlistMediaItem: playlistMediaItem,
                    onBackPressed: () => ref
                        .read(selectedExplorePlaylistProvider.notifier)
                        .setSelected(null),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              UIcons.regular.triangle_warning,
                              size: 40,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load playlist tracks',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$err',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ResonanceButton(
                              label: 'Retry',
                              icon: UIcons.regular.refresh,
                              onPressed: () => ref.invalidate(
                                onlinePlaylistTracksProvider(playlist.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePlaylistHeroAppBar extends StatelessWidget {
  final ExplorePlaylist playlist;
  final MediaItem playlistMediaItem;
  final VoidCallback onBackPressed;

  const _OnlinePlaylistHeroAppBar({
    required this.playlist,
    required this.playlistMediaItem,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
      automaticallyImplyLeading: false,
      leading: Center(
        child: AppBackButton(
          color: theme.colorScheme.onSurface,
          onTap: onBackPressed,
        ),
      ),
      actions: [
        Consumer(
          builder: (context, ref, _) => ReusableHoverIconButton(
            icon: UIcons.regular.add_folder,
            tooltip: 'Save to Playlists',
            iconSize: 18,
            onTap: () => MediaActionUtils.saveOnlinePlaylist(
              context,
              ref,
              playlistMediaItem,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 48, right: 16, bottom: 16),
        title: Text(
          playlist.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: theme.colorScheme.shadow.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (playlist.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: ThumbnailUtils.toCardResolution(playlist.thumbnailUrl),
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (c, u, e) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(UIcons.regular.list_music, size: 64, color: Colors.grey),
                ),
              )
            else
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(UIcons.regular.list_music, size: 64, color: Colors.grey),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: isDark ? 0.7 : 0.55),
                    theme.colorScheme.surface.withValues(alpha: 0.05),
                    theme.colorScheme.surface.withValues(alpha: isDark ? 0.85 : 0.75),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlinePlaylistHeaderActionsBar extends StatelessWidget {
  final int trackCount;
  final String? author;
  final VoidCallback? onPlayAll;
  final VoidCallback onSaveToPlaylists;
  final VoidCallback? onAddToQueue;

  const _OnlinePlaylistHeaderActionsBar({
    required this.trackCount,
    this.author,
    this.onPlayAll,
    required this.onSaveToPlaylists,
    this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (author != null && author!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                Text(
                  '$trackCount track${trackCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          if (onAddToQueue != null) ...[
            ReusableHoverIconButton(
              icon: UIcons.regular.list_music,
              tooltip: 'Add playlist to queue',
              iconSize: 20,
              padding: 6,
              onTap: onAddToQueue,
            ),
            const SizedBox(width: 8),
          ],
          ReusableHoverIconButton(
            icon: UIcons.regular.add_folder,
            tooltip: 'Save to Playlists',
            iconSize: 20,
            padding: 6,
            onTap: onSaveToPlaylists,
          ),
          if (trackCount > 0 && onPlayAll != null) ...[
            const SizedBox(width: 8),
            ReusableHoverIconButton(
              icon: UIcons.regular.play,
              tooltip: 'Play all tracks',
              iconSize: 22,
              padding: 6,
              onTap: onPlayAll,
            ),
          ],
        ],
      ),
    );
  }
}

class _OnlinePlaylistTrackTile extends ConsumerWidget {
  final MediaItem track;
  final int index;
  final VoidCallback onTap;

  const _OnlinePlaylistTrackTile({
    required this.track,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
        context: context,
        ref: ref,
        item: track,
        position: details.globalPosition,
      ),
      child: ListTile(
        mouseCursor: SystemMouseCursors.click,
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
              placeholderIcon: UIcons.regular.globe,
            ),
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
        onTap: onTap,
        onLongPress: () => MediaActionUtils.showMediaActions(
          context: context,
          ref: ref,
          item: track,
        ),
        trailing: OverflowMenuButton(
          tooltip: 'Actions',
          onTap: () => MediaActionUtils.showMediaActions(
            context: context,
            ref: ref,
            item: track,
          ),
        ),
      ),
    );
  }
}

