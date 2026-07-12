import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../../application/maintenance_provider.dart';
import 'package:resonance/core/widgets/danger_icon_button.dart';

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
        const Text(
          'Cache Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(UIcons.regular.hdd),
              title: const Text('Local Cache Management'),
              subtitle: Text('Total Size: ${maintenance.cacheSize}'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                const Divider(height: 1),
                _buildCacheTile(
                  context,
                  title: 'Metadata Cache',
                  size: notifier.formatBytes(folderSizes['metadata'] ?? 0),
                  onClear: () => _showClearDialog(context, 'metadata', 'Metadata Cache', notifier),
                ),
                _buildCacheTile(
                  context,
                  title: 'Translation Cache',
                  size: notifier.formatBytes(folderSizes['translate'] ?? 0),
                  onClear: () => _showClearDialog(context, 'translate', 'Translation Cache', notifier),
                ),
                _buildCacheTile(
                  context,
                  title: 'Images Cache',
                  size: notifier.formatBytes(folderSizes['images'] ?? 0),
                  onClear: () => _showClearDialog(context, 'images', 'Images Cache', notifier),
                ),
                
                // Stream (Nested Expansion)
                ExpansionTile(
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(UIcons.regular.waveform, size: 20),
                  ),
                  title: const Text('Stream Cache', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'Detailed audio, art, and lyrics',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                  children: [
                    _buildCacheTile(
                      context,
                      title: 'Stream Audio',
                      size: notifier.formatBytes(folderSizes['stream_audio'] ?? 0),
                      isNested: true,
                      onClear: () => _showClearDialog(context, 'stream_audio', 'Stream Audio Cache', notifier),
                    ),
                    _buildCacheTile(
                      context,
                      title: 'Stream Images',
                      size: notifier.formatBytes(folderSizes['stream_images'] ?? 0),
                      isNested: true,
                      onClear: () => _showClearDialog(context, 'stream_images', 'Stream Images Cache', notifier),
                    ),
                    _buildCacheTile(
                      context,
                      title: 'Stream Lyrics',
                      size: notifier.formatBytes(folderSizes['stream_lyrics'] ?? 0),
                      isNested: true,
                      onClear: () => _showClearDialog(context, 'stream_lyrics', 'Stream Lyrics Cache', notifier),
                    ),
                  ],
                ),
                
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextButton.icon(
                    onPressed: () => _showClearDialog(context, 'all', 'ALL CACHE DATA', notifier, isDoubleGuard: true),
                    icon: Icon(UIcons.regular.trash, color: Colors.redAccent),
                    label: const Text('Clear All Cache', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      builder: (ctx) => AlertDialog(
        title: Text('Clear $label?'),
        content: Text('Are you sure you want to delete all files in $label? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    if (isDoubleGuard) {
      if (!context.mounted) return;
      final secondConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.red[900],
          title: const Text('FINAL WARNING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'YOU ARE ABOUT TO DELETE EVERYTHING. ALL STREAMED AUDIO, IMAGES, AND METADATA WILL BE PURGED. ARE YOU ABSOLUTELY SURE?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NO, STOP!', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[900]),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('YES, PURGE EVERYTHING', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
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
