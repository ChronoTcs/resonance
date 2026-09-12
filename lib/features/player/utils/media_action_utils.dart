import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/presentation/widgets/online_playlist_actions_sheet.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';

class MediaActionUtils {
  static void showMediaActions({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
    String? playlistId,
  }) {
    if (item.type == 'playlist') {
      OnlinePlaylistActionsSheet.show(context: context, item: item);
      return;
    }

    MediaActionsBottomSheet.show(
      context: context,
      item: item,
      playlistId: playlistId,
      onDelete: (item.isLocal || item.id == null) ? () => confirmDelete(context, ref, item) : null,
    );
  }

  /// Displays desktop cursor-positioned context menu or mobile bottom sheet fallback.
  static Future<void> showTrackContextMenu({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
    required Offset position,
    String? playlistId,
    VoidCallback? onRemoveFromQueue,
  }) async {
    final bool useContextMenu = !AppBreakpoints.isCompact(context);

    if (item.type == 'playlist') {
      if (!useContextMenu) {
        OnlinePlaylistActionsSheet.show(context: context, item: item);
        return;
      }
      await OnlinePlaylistContextMenu.showAtPosition(
        context: context,
        ref: ref,
        item: item,
        position: position,
      );
      return;
    }

    if (!useContextMenu) {
      showMediaActions(
        context: context,
        ref: ref,
        item: item,
        playlistId: playlistId,
      );
      return;
    }

    await TrackContextMenu.showAtPosition(
      context: context,
      ref: ref,
      item: item,
      position: position,
      playlistId: playlistId,
      onRemoveFromQueue: onRemoveFromQueue,
    );
  }

  // ── Online Playlist Actions ────────────────────────────────────────────────

  /// Resolves full track list for an online YouTube/community playlist.
  static Future<List<MediaItem>> fetchOnlinePlaylistTracks(WidgetRef ref, String playlistId) async {
    if (!ref.read(networkConnectivityProvider).isOnline) {
      ref.read(notificationProvider.notifier).showNotification(
        'You\'re Offline',
        'Cannot load online playlist while disconnected.',
        silentOsNotification: true,
      );
      return [];
    }

    try {
      final tracks = await ref
          .read(youtubePlaylistRepositoryProvider)
          .fetchFullPlaylistContents(playlistId);
      return tracks
          .map(
            (t) => MediaItem(
              id: t.id,
              title: t.title,
              artist: t.author,
              thumbnailUrl: t.thumbnailUrl,
              path: t.id,
              type: 'audio',
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[MediaActionUtils] Failed to fetch playlist tracks: $e');
      return [];
    }
  }

  /// Plays full online playlist (starts track 1, enqueues rest).
  static Future<void> playOnlinePlaylist(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final playlistId = item.id ?? item.path;
    ref.read(notificationProvider.notifier).showNotification(
      'Loading Playlist',
      'Fetching "${item.title}" tracks...',
    );

    final mediaItems = await fetchOnlinePlaylistTracks(ref, playlistId);
    if (!context.mounted) return;

    if (mediaItems.isEmpty) {
      ref.read(notificationProvider.notifier).showNotification(
        'Playlist Empty',
        'No playable tracks found in playlist.',
        isError: true,
        silentOsNotification: true,
      );
      return;
    }

    await ref.read(audioProvider.notifier).playYouTubeTrack(mediaItems.first);
    if (mediaItems.length > 1) {
      ref.read(audioProvider.notifier).addTracksToQueue(mediaItems.sublist(1));
    }
  }

  /// Appends or inserts online playlist tracks into the playback queue.
  static Future<void> addOnlinePlaylistToQueue(
    BuildContext context,
    WidgetRef ref,
    MediaItem item, {
    bool playNext = false,
  }) async {
    final playlistId = item.id ?? item.path;
    ref.read(notificationProvider.notifier).showNotification(
      'Loading Playlist',
      'Fetching "${item.title}" tracks...',
    );

    final mediaItems = await fetchOnlinePlaylistTracks(ref, playlistId);
    if (!context.mounted) return;

    if (mediaItems.isEmpty) {
      ref.read(notificationProvider.notifier).showNotification(
        'Playlist Empty',
        'No tracks found to queue.',
        isError: true,
        silentOsNotification: true,
      );
      return;
    }

    if (playNext) {
      for (final track in mediaItems.reversed) {
        ref.read(audioProvider.notifier).playNext(track);
      }
      ref.read(notificationProvider.notifier).showNotification(
        'Playing Next',
        'Queued ${mediaItems.length} tracks to play next.',
        target: 'target:queue',
      );
    } else {
      ref.read(audioProvider.notifier).addTracksToQueue(mediaItems);
      ref.read(notificationProvider.notifier).showNotification(
        'Added to Queue',
        'Added ${mediaItems.length} tracks to queue.',
        target: 'target:queue',
      );
    }
  }

  /// Saves an online playlist into user's local playlists library.
  static Future<void> saveOnlinePlaylist(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final playlistId = item.id ?? item.path;
    ref.read(notificationProvider.notifier).showNotification(
      'Saving Playlist',
      'Importing "${item.title}" to library...',
    );

    final mediaItems = await fetchOnlinePlaylistTracks(ref, playlistId);
    if (!context.mounted) return;

    final newId = await ref.read(playlistProvider.notifier).createPlaylist(item.title);
    if (newId != null && mediaItems.isNotEmpty) {
      await ref.read(playlistProvider.notifier).addTracksToPlaylist(newId, mediaItems);
    }

    ref.read(notificationProvider.notifier).showNotification(
      'Playlist Saved',
      'Playlist "${item.title}" saved to your library!',
      target: newId != null ? 'target:playlist:$newId' : 'target:playlists',
      silentOsNotification: true,
    );
  }

  static void confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dlg) => Consumer(
        builder: (ctx, dialogRef, _) => ResonanceConfirmDialog(
          title: 'Delete Track',
          content: 'Permanently delete "${item.title}" from your device? This cannot be undone.',
          confirmLabel: 'Delete',
          isDanger: true,
          onConfirm: () {
            dialogRef.read(libraryProvider.notifier).deleteTrack(item);
            final audioState = dialogRef.read(audioProvider);
            if (audioState.currentTrack?.path == item.path) {
              dialogRef.read(audioProvider.notifier).next();
            }
          },
        ),
      ),
    );
  }

  /// Toggles blocked status of [item]. If newly blocked, skips track if currently playing
  /// and ejects from queue.
  static Future<void> toggleBlockTrack(
    BuildContext context,
    WidgetRef ref,
    MediaItem item, {
    VoidCallback? onManageBlocked,
  }) async {
    final blockedNotifier = ref.read(blockedTracksProvider.notifier);
    final isAlreadyBlocked = blockedNotifier.isBlocked(item.id, path: item.path);
    final trackId = item.id ?? item.path;

    if (isAlreadyBlocked) {
      await blockedNotifier.unblockTrack(trackId);
      ref.read(notificationProvider.notifier).showNotification(
        'Track Unblocked',
        'Unblocked "${item.title}".',
        target: 'target:blocked_tracks',
        silentOsNotification: true,
      );
    } else {
      await blockedNotifier.blockTrack(item);

      // Auto-skip if currently playing this track
      final audioState = ref.read(audioProvider);
      final currentTrackId = audioState.currentTrack?.id ?? audioState.currentTrack?.path;
      if (currentTrackId == trackId) {
        ref.read(audioProvider.notifier).next();
      }

      // Eject from queue if present
      ref.read(audioProvider.notifier).removeTrackFromQueueById(trackId);

      ref.read(notificationProvider.notifier).showNotification(
        'Track Blocked',
        'Blocked "${item.title}" from feed and queue.',
        target: 'target:blocked_tracks',
        actionLabel: 'Undo',
        onAction: () => blockedNotifier.unblockTrack(trackId),
        silentOsNotification: true,
      );
    }
  }
}
