import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/playlist/application/playlist_auto_cache_provider.dart';

/// Reusable toggle button for per-playlist offline auto-caching.
///
/// When OFF: displays a muted download icon.
/// When ON: displays an accent-tinted download icon with a pending dot indicator
/// if there are uncached tracks waiting for idle download.
class PlaylistAutoCacheToggleButton extends ConsumerWidget {
  final String playlistId;
  final double iconSize;
  final double padding;

  const PlaylistAutoCacheToggleButton({
    super.key,
    required this.playlistId,
    this.iconSize = 20.0,
    this.padding = 6.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAutoCache =
        ref.watch(playlistAutoCacheProvider).contains(playlistId);
    final uncachedAsync = ref.watch(playlistUncachedCountProvider(playlistId));
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final uncachedCount = uncachedAsync.value ?? 0;

    String tooltip;
    if (!isAutoCache) {
      tooltip = 'Auto-Cache: OFF (Click to cache tracks automatically when idle)';
    } else if (uncachedCount == 0) {
      tooltip = 'Auto-Cache: ON (All streaming tracks are cached offline)';
    } else {
      tooltip =
          'Auto-Cache: ON ($uncachedCount track${uncachedCount == 1 ? '' : 's'} pending idle download)';
    }

    return ReusableHoverIconButton(
      tooltip: tooltip,
      padding: padding,
      backgroundColor: isAutoCache
          ? primary.withValues(alpha: 0.14)
          : Colors.transparent,
      hoverColor: primary,
      onTap: () =>
          ref.read(playlistAutoCacheProvider.notifier).toggleAutoCache(playlistId),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            AppIcons.download,
            size: iconSize,
            color: isAutoCache
                ? primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          if (isAutoCache && uncachedCount > 0)
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
