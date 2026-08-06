import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';

import '../../../download/application/providers/download_settings_provider.dart';

class DownloadsSettingsSection extends ConsumerWidget {
  const DownloadsSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(downloadSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final notifier = ref.read(downloadSettingsProvider.notifier);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Downloads Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Default Source Selector
            ResonanceSelector<String>(
              icon: UIcons.regular.globe,
              title: 'Default Source',
              subtitle: 'Select default download provider',
              value: settings.defaultSource,
              onChanged: (val) {
                notifier.saveSettings(settings.copyWith(defaultSource: val));
              },
              items: const [
                ResonanceSelectorItem(value: 'ytmusic', label: 'YouTube Music'),
                ResonanceSelectorItem(value: 'youtube', label: 'YouTube'),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              'Advanced Limits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Grouped Advanced Limits Container
            Material(
              color: Theme.of(context).colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  _buildNumericTileRow(
                    context,
                    label: 'Max Concurrent Downloads',
                    value: settings.maxConcurrent,
                    min: 1,
                    max: 8,
                    onChanged: (v) => notifier.saveSettings(settings.copyWith(maxConcurrent: v)),
                  ),
                  const Divider(height: 1),
                  _buildNumericTileRow(
                    context,
                    label: 'Max Retry Limit',
                    value: settings.maxRetries,
                    min: 0,
                    max: 10,
                    onChanged: (v) => notifier.saveSettings(settings.copyWith(maxRetries: v)),
                  ),
                  const Divider(height: 1),
                  _buildNumericTileRow(
                    context,
                    label: 'Connection Timeout (seconds)',
                    value: settings.connectionTimeout,
                    min: 5,
                    max: 120,
                    onChanged: (v) => notifier.saveSettings(settings.copyWith(connectionTimeout: v)),
                  ),
                  const Divider(height: 1),
                  _buildNumericTileRow(
                    context,
                    label: 'Segments per Download',
                    value: settings.fragmentsPerDownload,
                    min: 1,
                    max: 16,
                    onChanged: (v) => notifier.saveSettings(settings.copyWith(fragmentsPerDownload: v)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildNumericTileRow(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReusableHoverIconButton(
                icon: UIcons.regular.minus,
                iconSize: 14,
                padding: 6,
                isDisabled: value <= min,
                onTap: () => onChanged(value - 1),
                tooltip: 'Decrease',
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              ReusableHoverIconButton(
                icon: UIcons.regular.add,
                iconSize: 14,
                padding: 6,
                isDisabled: value >= max,
                onTap: () => onChanged(value + 1),
                tooltip: 'Increase',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
