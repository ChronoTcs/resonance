import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

/// Standalone full-bleed Speed Dial card matching YouTube Music design with responsive hover.
///
/// Features:
/// - 1:1 square full-bleed artwork with 12dp rounded corners.
/// - Desktop hover scaling, elevated shadow, border lighting, and centered play button overlay.
/// - Bottom dark gradient overlay with bold white title and trailing chevron (>).
/// - Prominent 2.5dp white outline border when track is currently active/playing.
class SpeedDialCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final double size;
  final VoidCallback? onTap;

  const SpeedDialCard({
    super.key,
    required this.item,
    this.size = 115,
    this.onTap,
  });

  @override
  ConsumerState<SpeedDialCard> createState() => _SpeedDialCardState();
}

class _SpeedDialCardState extends ConsumerState<SpeedDialCard> {
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

    if (localArtPath != null && File(localArtPath).existsSync()) {
      return Image.file(
        File(localArtPath),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(theme),
      );
    }

    if (widget.item.thumbnailUrl != null && widget.item.thumbnailUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: ThumbnailUtils.toCardResolution(widget.item.thumbnailUrl!),
        width: widget.size,
        height: widget.size,
        memCacheWidth: 400,
        memCacheHeight: 400,
        fit: BoxFit.cover,
        placeholder: (_, _) => _buildPlaceholder(theme),
        errorWidget: (_, _, _) => _buildPlaceholder(theme),
      );
    }

    return _buildPlaceholder(theme);
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
    final currentTrack = ref.watch(audioProvider.select((s) => s.currentTrack));

    final isCurrent = currentTrack != null &&
        ((widget.item.id != null && widget.item.id!.isNotEmpty && widget.item.id == currentTrack.id) ||
            (widget.item.path.isNotEmpty && widget.item.path == currentTrack.path));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.touch) return;
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) {
          setState(() => _isHovered = false);
        }
      },
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedScale(
          scale: _isHovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : (_isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isCurrent
                  ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                  : (_isHovered
                      ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6), width: 1.5)
                      : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15), width: 1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Full-bleed Artwork
                  _buildArtwork(theme),

                  // 2. Bottom Dark Gradient Overlay
                  const _SpeedDialGradientOverlay(),

                  // 3. Center Hover Play Action Button
                  if (_isHovered) const _SpeedDialHoverPlayOverlay(),

                  // 4. Bottom Text & Chevron Arrow
                  _SpeedDialBottomTitleRow(title: widget.item.title),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedDialGradientOverlay extends StatelessWidget {
  const _SpeedDialGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.20),
              Colors.black.withValues(alpha: 0.85),
              Colors.black,
            ],
            stops: const [0.20, 0.48, 0.76, 1.0],
          ),
        ),
      ),
    );
  }
}

class _SpeedDialHoverPlayOverlay extends StatelessWidget {
  const _SpeedDialHoverPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.75),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedDialBottomTitleRow extends StatelessWidget {
  final String title;

  const _SpeedDialBottomTitleRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 6,
      bottom: 8,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            size: 16,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

