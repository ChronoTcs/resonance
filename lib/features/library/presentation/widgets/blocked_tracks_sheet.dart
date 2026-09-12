import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/overlays/floating_sheet_shell.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/library/data/models/blocked_track.dart';

class BlockedTracksSheet extends ConsumerWidget {
  const BlockedTracksSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const BlockedTracksSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blockedList = ref.watch(blockedTracksProvider);

    return FloatingSheetShell(
      maxWidth: 480,
      maxHeight: 560,
      title: 'Blocked Tracks',
      icon: UIcons.regular.ban,
      onClose: () => Navigator.pop(context),
      children: [
        if (blockedList.isEmpty)
          _buildEmptyState(theme)
        else ...[
          _buildHeaderInfo(theme, ref, blockedList.length),
          const SizedBox(height: 12),
          ...blockedList.map((track) => _BlockedTrackTile(track: track)),
        ],
      ],
    );
  }

  Widget _buildHeaderInfo(ThemeData theme, WidgetRef ref, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$count song${count == 1 ? '' : 's'} hidden from feed & queue',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        ReusableHoverIconButton(
          tooltip: 'Unblock all tracks',
          hoverColor: theme.colorScheme.primary,
          padding: 0,
          scaleOnHover: 1.05,
          borderRadius: BorderRadius.circular(6),
          onTap: () => ref.read(blockedTracksProvider.notifier).clearAll(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Unblock All',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                UIcons.regular.shield_check,
                size: 26,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Blocked Tracks',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Songs you block via right-click or song options will never appear in your feeds or autoplay queue.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedTrackTile extends ConsumerWidget {
  final BlockedTrack track;

  const _BlockedTrackTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty
                ? Image.network(
                    track.thumbnailUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackArtwork(theme),
                  )
                : _fallbackArtwork(theme),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist ?? 'Unknown Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.check,
            tooltip: 'Unblock',
            iconSize: 16,
            padding: 8,
            onTap: () {
              ref.read(blockedTracksProvider.notifier).unblockTrack(track.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _fallbackArtwork(ThemeData theme) {
    return Container(
      width: 44,
      height: 44,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        UIcons.regular.music,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
