import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:resonance/core/utils/app_icons.dart';
import '../../features/library/data/models/media_item.dart';
import '../data/services/media_cache_service.dart';

class MediaArtworkWidget extends ConsumerStatefulWidget {
  final MediaItem item;
  final double width;
  final double height;
  final double borderRadius;
  final IconData? placeholderIcon;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;

  const MediaArtworkWidget({
    super.key,
    required this.item,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 6,
    this.placeholderIcon,
    this.fit = BoxFit.cover,
    this.color,
    this.colorBlendMode,
  });

  @override
  ConsumerState<MediaArtworkWidget> createState() => _MediaArtworkWidgetState();
}

class _MediaArtworkWidgetState extends ConsumerState<MediaArtworkWidget> {
  String? _resolvedThumbnailUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant MediaArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path || oldWidget.item.thumbnailUrl != widget.item.thumbnailUrl) {
      _resolveThumbnail();
    }
  }

  Future<void> _resolveThumbnail() async {
    if (widget.item.albumArt != null) {
      if (mounted) setState(() => _resolvedThumbnailUrl = null);
      return;
    }
    
    if (widget.item.thumbnailUrl != null) {
      if (mounted) setState(() => _resolvedThumbnailUrl = widget.item.thumbnailUrl);
      return;
    }

    if (!widget.item.path.startsWith('http')) {
      if (mounted) setState(() => _isLoading = true);
      // Attempt to find inside cache
      final songId = widget.item.id ?? widget.item.path;
      final cache = ref.read(mediaCacheServiceProvider);
      final path = await cache.getCachedArtPath(songId);
      if (mounted) {
        setState(() {
          _resolvedThumbnailUrl = path;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: widget.width,
      height: widget.height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          widget.placeholderIcon ?? AppIcons.music,
          color: theme.colorScheme.onSurfaceVariant,
          size: widget.width == double.infinity ? 48 : widget.width * 0.5,
        ),
      ),
    );

    Widget imageWidget;

    if (widget.item.albumArt != null) {
      imageWidget = Image.memory(
        widget.item.albumArt!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (_resolvedThumbnailUrl != null) {
      if (_resolvedThumbnailUrl!.startsWith('http')) {
        imageWidget = CachedNetworkImage(
          imageUrl: _resolvedThumbnailUrl!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          color: widget.color,
          colorBlendMode: widget.colorBlendMode,
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        );
      } else {
        imageWidget = Image.file(
          File(_resolvedThumbnailUrl!),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          color: widget.color,
          colorBlendMode: widget.colorBlendMode,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } else {
      imageWidget = fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: _isLoading ? fallback : imageWidget,
    );
  }
}

