import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/data/models/explore_item.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/docked/components/audio_track_info.dart';
import 'package:resonance/features/explore/presentation/providers/recent_searches_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

class ExploreMusicTile extends ConsumerWidget {
  final ExploreItem item;

  const ExploreMusicTile({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Duration trackDuration = Duration.zero;
    final parts = item.duration.split(':');
    if (parts.length == 2) {
      trackDuration = Duration(
        minutes: int.tryParse(parts[0]) ?? 0,
        seconds: int.tryParse(parts[1]) ?? 0,
      );
    } else if (parts.length == 3) {
      trackDuration = Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }

    final mediaItem = MediaItem(
      id: item.id,
      path: (item.url.isNotEmpty && !item.url.startsWith('http')) ? item.url : item.id,
      title: item.title,
      artist: item.author,
      album: item.album,
      thumbnailUrl: item.thumbnailUrl,
      duration: trackDuration,
      type: item.type,
    );

    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
        context: context,
        ref: ref,
        item: mediaItem,
        position: details.globalPosition,
      ),
      child: ListTile(
        mouseCursor: SystemMouseCursors.click,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: ThumbnailUtils.toCardResolution(item.thumbnailUrl),
            width: 60,
            height: 60,
            memCacheWidth: 400,
            memCacheHeight: 400,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(AppIcons.music),
            ),
            errorWidget: (context, url, error) {
              final fallbackUrl = ThumbnailUtils.getFallbackResolution(url);
              if (fallbackUrl != null && fallbackUrl != url) {
                return CachedNetworkImage(
                  imageUrl: ThumbnailUtils.toCardResolution(fallbackUrl),
                  width: 60,
                  height: 60,
                  memCacheWidth: 400,
                  memCacheHeight: 400,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(AppIcons.music),
                  ),
                  errorWidget: (context, _, _) => Icon(UIcons.regular.exclamation),
                );
              }
              return Icon(UIcons.regular.exclamation);
            },
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            TrackTypeChip(isVideo: item.type == 'video'),
          ],
        ),
        subtitle: Text(
          (item.duration != '0:00' && item.duration.isNotEmpty)
              ? '${item.author} • ${item.duration}'
              : item.author,
        ),
        onTap: () {
          ref.read(recentSearchesProvider.notifier).addSearchTrack(mediaItem);
          ref.read(audioProvider.notifier).playYouTubeTrack(mediaItem);
        },
        onLongPress: () {
          MediaActionsBottomSheet.show(
            context: context,
            item: mediaItem,
            video: item.originalVideo,
          );
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            OverflowMenuButton(
              tooltip: 'Actions',
              onTap: () {
                MediaActionsBottomSheet.show(
                  context: context,
                  item: mediaItem,
                  video: item.originalVideo,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
