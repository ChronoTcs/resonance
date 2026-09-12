import 'dart:ui' show ImageFilter;
import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/presentation/widgets/playlist_actions_bottom_sheet.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/features/playlist/presentation/widgets/music_picker_sheet.dart';
import 'package:resonance/features/playlist/presentation/widgets/auto_continue_toggle_button.dart';
import 'package:resonance/features/playlist/presentation/widgets/playlist_auto_cache_toggle_button.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.showBackButton = true,
  });

  final String playlistId;
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);

    return Scaffold(
      body: playlistsAsync.when(
        data: (state) {
          final playlist = state.getById(playlistId);
          if (playlist == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Playlist not found')),
            );
          }

          final tracks = playlist.tracks;

          return Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SilkyCustomScrollView(
                  slivers: [
              _PlaylistHeroAppBar(
                playlist: playlist,
                showBackButton: showBackButton,
                onBackPressed: () => ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(null),
                onRepair: () async {
                  final libraryItems = ref.read(libraryProvider).allMedia;
                  final count = await ref
                      .read(playlistProvider.notifier)
                      .repairPlaylist(playlistId, libraryItems);

                  ref.read(notificationProvider.notifier).showNotification(
                    'Playlist Repair',
                    count > 0
                        ? 'Repaired $count broken tracks!'
                        : 'No broken tracks found or no matches in library.',
                    isError: count == 0,
                    target: 'target:playlist:$playlistId',
                    silentOsNotification: true,
                  );
                },
                onAddMusic: () => MusicPickerSheet.show(context, playlistId),
                onDeleteSuccess: () => ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(null),
              ),
              SliverToBoxAdapter(
                child: _PlaylistHeaderActionsBar(
                  playlistId: playlistId,
                  trackCount: tracks.length,
                  onPlayAll: tracks.isNotEmpty
                      ? () => ref.read(audioProvider.notifier).playPlaylist(tracks, initialIndex: 0, playlistId: playlistId)
                      : null,
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
                    return _PlaylistDetailTrackTile(
                      track: track,
                      playlistId: playlistId,
                      onTap: () => ref.read(audioProvider.notifier).playPlaylist(tracks, initialIndex: i, playlistId: playlistId),
                      onRemove: () {
                        ref
                            .read(playlistProvider.notifier)
                            .removeTrackFromPlaylist(playlistId, track.id ?? track.path);
                      },
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
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

class _PlaylistHeroAppBar extends StatelessWidget {
  final dynamic playlist;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback onRepair;
  final VoidCallback onAddMusic;
  final VoidCallback onDeleteSuccess;

  const _PlaylistHeroAppBar({
    required this.playlist,
    required this.showBackButton,
    required this.onBackPressed,
    required this.onRepair,
    required this.onAddMusic,
    required this.onDeleteSuccess,
  });

  Widget _buildBanner(ThemeData theme, bool isDark) {
    final tracks = playlist.tracks;
    final firstTrack = tracks.isNotEmpty ? tracks.first : null;
    final bool isLiked = playlist.name == 'Liked Songs';

    if (isLiked) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.primary.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            UIcons.solid.heart,
            size: 88,
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
        ),
      );
    } else if (firstTrack != null) {
      return MediaArtworkWidget(
        item: firstTrack,
        width: double.infinity,
        height: double.infinity,
        borderRadius: 0,
        placeholderIcon: UIcons.regular.list_music,
      );
    }

    return Container(
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
    );
  }

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
      leading: showBackButton && onBackPressed != null
          ? Center(
              child: AppBackButton(
                color: theme.colorScheme.onSurface,
                onTap: onBackPressed,
              ),
            )
          : null,
      actions: [
        ReusableHoverIconButton(
          icon: UIcons.regular.refresh,
          tooltip: 'Repair Playlist',
          iconSize: 18,
          onTap: onRepair,
        ),
        ReusableHoverIconButton(
          icon: UIcons.regular.add,
          tooltip: 'Add Music',
          iconSize: 18,
          onTap: onAddMusic,
        ),
        Consumer(
          builder: (context, ref, _) => ReusableHoverIconButton(
            icon: AppIcons.moreVert,
            iconSize: 18,
            tooltip: 'More options',
            onTap: () => PlaylistActionsBottomSheet.show(
              context: context,
              ref: ref,
              playlist: playlist,
              onDeleteSuccess: onDeleteSuccess,
            ),
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
            background: Stack(
              fit: StackFit.expand,
              children: [
                _buildBanner(theme, isDark),
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
        ),
      ),
    );
  }
}

class _PlaylistHeaderActionsBar extends StatelessWidget {
  final String playlistId;
  final int trackCount;
  final VoidCallback? onPlayAll;

  const _PlaylistHeaderActionsBar({
    required this.playlistId,
    required this.trackCount,
    this.onPlayAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$trackCount track${trackCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          if (trackCount > 0) ...[
            PlaylistAutoCacheToggleButton(
              playlistId: playlistId,
              iconSize: 20,
              padding: 6,
            ),
            const SizedBox(width: 8),
          ],
          if (trackCount > 0 && onPlayAll != null) ...[
            AutoContinueToggleButton(
              playlistId: playlistId,
              iconSize: 20,
              padding: 6,
            ),
            const SizedBox(width: 8),
            ReusableHoverIconButton(
              icon: UIcons.regular.play,
              tooltip: 'Play all tracks',
              iconSize: 22,
              onTap: onPlayAll,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaylistDetailTrackTile extends ConsumerWidget {
  final MediaItem track;
  final String playlistId;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistDetailTrackTile({
    required this.track,
    required this.playlistId,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = track.isStreaming;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
        context: context,
        ref: ref,
        item: track,
        position: details.globalPosition,
        playlistId: playlistId,
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
        onTap: onTap,
        onLongPress: () => MediaActionUtils.showMediaActions(
          context: context,
          ref: ref,
          item: track,
          playlistId: playlistId,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OverflowMenuButton(
              tooltip: 'Actions',
              onTap: () => MediaActionUtils.showMediaActions(
                context: context,
                ref: ref,
                item: track,
                playlistId: playlistId,
              ),
            ),
            const SizedBox(width: 4),
            ReusableHoverIconButton(
              icon: UIcons.regular.minus,
              tooltip: 'Remove from playlist',
              iconSize: 16,
              padding: 4,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

