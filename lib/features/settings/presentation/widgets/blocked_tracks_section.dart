import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';
import 'package:resonance/features/library/data/models/blocked_track.dart';

class BlockedTracksSection extends ConsumerStatefulWidget {
  const BlockedTracksSection({super.key});

  @override
  ConsumerState<BlockedTracksSection> createState() => _BlockedTracksSectionState();
}

class _BlockedTracksSectionState extends ConsumerState<BlockedTracksSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allBlocked = ref.watch(blockedTracksProvider);

    final filtered = _query.isEmpty
        ? allBlocked
        : allBlocked.where((t) {
            final q = _query.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                (t.artist?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryHeader(theme, allBlocked.length),
        const SizedBox(height: 16),
        if (allBlocked.isNotEmpty) ...[
          _buildSearchBar(theme),
          const SizedBox(height: 16),
        ],
        if (allBlocked.isEmpty)
          _buildEmptyState(theme)
        else if (filtered.isEmpty)
          _buildNoSearchResults(theme)
        else
          ...filtered.map((track) => _BlockedTrackRow(track: track)),
      ],
    );
  }

  Widget _buildSummaryHeader(ThemeData theme, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              UIcons.regular.ban,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalCount Blocked Song${totalCount == 1 ? '' : 's'}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Blocked songs will never appear in your Home feed or auto-play queue.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (totalCount > 0)
            ReusableHoverIconButton(
              tooltip: 'Unblock all tracks',
              hoverColor: theme.colorScheme.error,
              padding: 0,
              scaleOnHover: 1.05,
              borderRadius: BorderRadius.circular(6),
              onTap: () => ref.read(blockedTracksProvider.notifier).clearAll(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Unblock All',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v.trim()),
      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search blocked songs or artists...',
        prefixIcon: Icon(UIcons.regular.search, size: 16, color: theme.colorScheme.onSurfaceVariant),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
          maxWidth: 36,
          maxHeight: 32,
        ),
        suffixIcon: _query.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: ReusableHoverIconButton(
                      icon: UIcons.regular.cross_small,
                      tooltip: 'Clear search',
                      iconSize: 13,
                      padding: 2.0,
                      scaleOnHover: 1.0,
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                  ),
                ),
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            UIcons.regular.shield_check,
            size: 48,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Blocked Songs',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'You haven\'t blocked any songs yet. Use the right-click menu or 3-dots on any song to block it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Text(
        'No blocked songs match "$_query"',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _BlockedTrackRow extends ConsumerWidget {
  final BlockedTrack track;

  const _BlockedTrackRow({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
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
                    width: 42,
                    height: 42,
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
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
          const SizedBox(width: 8),
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
      width: 42,
      height: 42,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        UIcons.regular.music,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
