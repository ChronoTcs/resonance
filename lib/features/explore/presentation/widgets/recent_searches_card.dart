import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Standalone Recent Search card matching Picture 1 ("Penelusuran terbaru").
///
/// Features:
/// - 105x105 dp square album artwork with 8dp rounded corners.
/// - Single-line white title text underneath with ellipsis (clean, minimal, no artist subtitle).
class RecentSearchesCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final double size;
  final VoidCallback? onTap;

  const RecentSearchesCard({
    super.key,
    required this.item,
    this.size = 105,
    this.onTap,
  });

  @override
  ConsumerState<RecentSearchesCard> createState() => _RecentSearchesCardState();
}

class _RecentSearchesCardState extends ConsumerState<RecentSearchesCard> {
  bool _isHovered = false;

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (widget.item.isLocal ||
        (widget.item.path.isNotEmpty && !widget.item.isStreaming && !widget.item.path.startsWith('http'))) {
      ref.read(audioProvider.notifier).playTrack(widget.item);
    } else {
      ref.read(audioProvider.notifier).playYouTubeTrack(widget.item);
    }
  }

  Widget _buildArtwork(ThemeData theme) {
    final localArtPath =
        (widget.item.thumbnailUrl != null && !widget.item.thumbnailUrl!.startsWith('http'))
            ? widget.item.thumbnailUrl
            : null;

    Widget img;
    if (localArtPath != null && File(localArtPath).existsSync()) {
      img = Image.file(
        File(localArtPath),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(theme),
      );
    } else if (widget.item.thumbnailUrl != null && widget.item.thumbnailUrl!.startsWith('http')) {
      img = CachedNetworkImage(
        imageUrl: ThumbnailUtils.toCardResolution(widget.item.thumbnailUrl!),
        width: widget.size,
        height: widget.size,
        memCacheWidth: 400,
        memCacheHeight: 400,
        fit: BoxFit.cover,
        placeholder: (_, _) => _buildPlaceholder(theme),
        errorWidget: (_, _, _) => _buildPlaceholder(theme),
      );
    } else {
      img = _buildPlaceholder(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: img,
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: widget.size,
      height: widget.size,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(AppIcons.music, size: 28, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: _handleTap,
        onSecondaryTapDown: (details) => MediaActionUtils.showTrackContextMenu(
          context: context,
          ref: ref,
          item: widget.item,
          position: details.globalPosition,
        ),
        onLongPress: () => MediaActionUtils.showMediaActions(context: context, ref: ref, item: widget.item),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: widget.size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildArtwork(theme),
                const SizedBox(height: 6),
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.1,
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
