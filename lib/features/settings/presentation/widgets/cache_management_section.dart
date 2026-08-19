import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../../application/maintenance_provider.dart';

class CacheManagementSection extends ConsumerWidget {
  const CacheManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final maintenance = ref.watch(maintenanceProvider);
    final notifier = ref.read(maintenanceProvider.notifier);
    final folderSizes = maintenance.folderSizes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cache Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            ReusableHoverIconButton(
              icon: UIcons.regular.refresh,
              tooltip: 'Recalculate storage sizes',
              iconSize: 16,
              onTap: () => notifier.forceRecalculate(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 1. Local Music Cache ────────────────────────────────────────────
        _buildSection(
          context,
          theme: theme,
          icon: UIcons.regular.headphones,
          title: 'Local Music Cache',
          subtitle: 'Downloaded songs, lyrics & thumbnails',
          totalSize: notifier.formatBytes(
            (folderSizes['local_music'] ?? 0) +
            (folderSizes['local_lyrics'] ?? 0) +
            (folderSizes['local_images'] ?? 0),
          ),
          children: [
            const Divider(height: 1),
            _buildCacheTile(
              context,
              title: 'Downloaded Music Files',
              size: notifier.formatBytes(folderSizes['local_music'] ?? 0),
              onClear: () => _showClearDialog(context, 'local_music', 'Downloaded Music Files', notifier),
            ),
            _buildCacheTile(
              context,
              title: 'Local Lyrics',
              size: notifier.formatBytes(folderSizes['local_lyrics'] ?? 0),
              onClear: () => _showClearDialog(context, 'local_lyrics', 'Local Lyrics', notifier),
            ),
            _buildCacheTile(
              context,
              title: 'Local Thumbnails',
              size: notifier.formatBytes(folderSizes['local_images'] ?? 0),
              onClear: () => _showClearDialog(context, 'local_images', 'Local Thumbnails', notifier),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: ResonanceButton(
                  onPressed: () => _showClearDialog(context, 'group_local', 'Local Music Cache', notifier),
                  icon: UIcons.regular.trash,
                  label: 'Clear Local Music Cache',
                  style: ResonanceButtonStyle.danger,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ── 2. Stream Music Cache ───────────────────────────────────────────
        _buildSection(
          context,
          theme: theme,
          icon: UIcons.regular.waveform,
          title: 'Stream Music Cache',
          subtitle: 'Online audio streams, art & lyrics',
          totalSize: notifier.formatBytes(
            (folderSizes['stream_audio'] ?? 0) +
            (folderSizes['stream_images'] ?? 0) +
            (folderSizes['stream_lyrics'] ?? 0),
          ),
          children: [
            const Divider(height: 1),
            _buildCacheTile(
              context,
              title: 'Streamed Audio',
              size: notifier.formatBytes(folderSizes['stream_audio'] ?? 0),
              onClear: () => _showClearDialog(context, 'stream_audio', 'Streamed Audio Cache', notifier),
            ),
            _buildCacheTile(
              context,
              title: 'Streamed Images',
              size: notifier.formatBytes(folderSizes['stream_images'] ?? 0),
              onClear: () => _showClearDialog(context, 'stream_images', 'Streamed Images Cache', notifier),
            ),
            _buildCacheTile(
              context,
              title: 'Streamed Lyrics',
              size: notifier.formatBytes(folderSizes['stream_lyrics'] ?? 0),
              onClear: () => _showClearDialog(context, 'stream_lyrics', 'Streamed Lyrics Cache', notifier),
            ),
            const Divider(height: 1),
            // ── Stream Cache Settings (Single Horizontal Row Option Selectors) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  ResonanceHorizontalSelector<int>(
                    icon: UIcons.regular.hdd,
                    title: 'Max Stream Audio Cache Limit',
                    subtitle: 'Maximum storage limit before oldest stream files are evicted',
                    value: ref.watch(streamCacheLimitGbProvider),
                    onChanged: (val) => ref.read(streamCacheLimitGbProvider.notifier).setLimitGb(val),
                    items: const [
                      ResonanceSelectorItem(value: 2, label: '2 GB'),
                      ResonanceSelectorItem(value: 5, label: '5 GB'),
                      ResonanceSelectorItem(value: 10, label: '10 GB (Default)'),
                      ResonanceSelectorItem(value: 15, label: '15 GB'),
                      ResonanceSelectorItem(value: 20, label: '20 GB'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ResonanceHorizontalSelector<int>(
                    icon: UIcons.regular.clock,
                    title: 'Track Activity Retention',
                    subtitle: 'Days to retain playback history timestamp per stream track',
                    value: ref.watch(streamTrackRetentionDaysProvider),
                    onChanged: (val) => ref.read(streamTrackRetentionDaysProvider.notifier).setDays(val),
                    items: const [
                      ResonanceSelectorItem(value: 7, label: '7 Days'),
                      ResonanceSelectorItem(value: 14, label: '14 Days'),
                      ResonanceSelectorItem(value: 30, label: '30 Days (Default)'),
                      ResonanceSelectorItem(value: 60, label: '60 Days'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ResonanceHorizontalSelector<int>(
                    icon: UIcons.regular.trash,
                    title: 'Orphaned Secondary Cache Retention',
                    subtitle: 'Days to retain images & lyrics after audio stream is erased',
                    value: ref.watch(secondaryCacheRetentionDaysProvider),
                    onChanged: (val) => ref.read(secondaryCacheRetentionDaysProvider.notifier).setDays(val),
                    items: const [
                      ResonanceSelectorItem(value: 3, label: '3 Days'),
                      ResonanceSelectorItem(value: 7, label: '7 Days (Default)'),
                      ResonanceSelectorItem(value: 14, label: '14 Days'),
                      ResonanceSelectorItem(value: 30, label: '30 Days'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: ResonanceButton(
                  onPressed: () => _showClearDialog(context, 'group_stream', 'Stream Music Cache', notifier),
                  icon: UIcons.regular.trash,
                  label: 'Clear Stream Music Cache',
                  style: ResonanceButtonStyle.danger,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ── 3. System App Cache ─────────────────────────────────────────────
        _buildSection(
          context,
          theme: theme,
          icon: UIcons.regular.hdd,
          title: 'System App Cache',
          subtitle: 'Metadata, translations & player temp files',
          totalSize: notifier.formatBytes(
            (folderSizes['metadata'] ?? 0) +
            (folderSizes['translate'] ?? 0) +
            (folderSizes['images'] ?? 0),
          ),
          children: [
            const Divider(height: 1),
            _buildCacheTile(
              context,
              title: 'Track Metadata',
              size: notifier.formatBytes(folderSizes['metadata'] ?? 0),
              onClear: () => _showClearDialog(context, 'metadata', 'Track Metadata Cache', notifier),
            ),
            _buildCacheTile(
              context,
              title: 'Translation Cache',
              size: notifier.formatBytes(folderSizes['translate'] ?? 0),
              onClear: () => _showClearDialog(context, 'translate', 'Translation Cache', notifier),
            ),
            _buildCacheTile(
              context,
              title: 'System Images',
              size: notifier.formatBytes(folderSizes['images'] ?? 0),
              onClear: () => _showClearDialog(context, 'images', 'System Images Cache', notifier),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: ResonanceButton(
                  onPressed: () => _showClearDialog(context, 'group_system', 'System App Cache', notifier),
                  icon: UIcons.regular.trash,
                  label: 'Clear System App Cache',
                  style: ResonanceButtonStyle.danger,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),
        Text(
          'Total: ${maintenance.cacheSize}',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required String totalSize,
    required List<Widget> children,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, size: 18, color: theme.primaryColor),
          title: Text(title),
          subtitle: Text('$subtitle  ·  $totalSize'),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: children,
        ),
      ),
    );
  }

  Widget _buildCacheTile(
    BuildContext context, {
    required String title,
    required String size,
    required VoidCallback onClear,
    bool isNested = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: isNested ? 48 : 32, right: 16),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(size, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      trailing: DangerIconButton(
        iconSize: 20,
        onTap: onClear,
        tooltip: 'Clear $title',
      ),
    );
  }

  Future<void> _showClearDialog(
    BuildContext context,
    String category,
    String label,
    MaintenanceNotifier notifier, {
    bool isDoubleGuard = false,
  }) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ResonanceConfirmDialog(
        title: 'Clear $label?',
        content: 'Are you sure you want to delete all files in $label? This action cannot be undone.',
        confirmLabel: 'Clear',
        isDanger: true,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );

    if (firstConfirm != true) return;

    if (isDoubleGuard) {
      if (!context.mounted) return;
      final secondConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => ResonanceConfirmDialog(
          title: 'Final Warning',
          content: 'You are about to delete ALL cache data — streamed audio, images, and metadata will be permanently purged. Are you absolutely sure?',
          confirmLabel: 'Yes, Purge Everything',
          cancelLabel: 'No, Stop!',
          isDanger: true,
          onConfirm: () => Navigator.of(ctx).pop(true),
        ),
      );
      if (secondConfirm != true) return;
    }

    await notifier.clearCategory(category);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully cleared $label.')),
    );
  }
}
