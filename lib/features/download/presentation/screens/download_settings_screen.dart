import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/features/download/data/repositories/download_settings_provider.dart';

class DownloadSettingsScreen extends ConsumerWidget {
  const DownloadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(downloadSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Download Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Output Paths ──────────────────────────────────────
              _SectionHeader(
                label: 'Output Paths',
                icon: Icons.folder_outlined,
              ),
              const SizedBox(height: 8),

              _PathTile(
                label: 'Music Folder',
                subtitle: settings.musicOutputPath,
                icon: Icons.music_note,
                onPick: () async {
                  final dir = await FilePicker.platform.getDirectoryPath();
                  if (dir != null) {
                    ref
                        .read(downloadSettingsProvider.notifier)
                        .saveSettings(settings.copyWith(musicOutputPath: dir));
                  }
                },
              ),
              const SizedBox(height: 8),

              _PathTile(
                label: 'Lyrics Folder',
                subtitle: settings.lyricsOutputPath,
                icon: Icons.lyrics_outlined,
                onPick: () async {
                  final dir = await FilePicker.platform.getDirectoryPath();
                  if (dir != null) {
                    ref
                        .read(downloadSettingsProvider.notifier)
                        .saveSettings(settings.copyWith(lyricsOutputPath: dir));
                  }
                },
              ),
              const SizedBox(height: 8),

              _PathTile(
                label: 'Video Folder',
                subtitle: settings.videoOutputPath,
                icon: Icons.movie_outlined,
                onPick: () async {
                  final dir = await FilePicker.platform.getDirectoryPath();
                  if (dir != null) {
                    ref
                        .read(downloadSettingsProvider.notifier)
                        .saveSettings(settings.copyWith(videoOutputPath: dir));
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── Quality ───────────────────────────────────────────
              _SectionHeader(label: 'Audio Quality', icon: Icons.high_quality),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MP3 Bitrate', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '128', label: Text('128 kbps')),
                          ButtonSegment(value: '192', label: Text('192 kbps')),
                          ButtonSegment(value: '320', label: Text('320 kbps')),
                        ],
                        selected: {settings.audioQuality},
                        onSelectionChanged: (s) {
                          ref
                              .read(downloadSettingsProvider.notifier)
                              .saveSettings(
                                settings.copyWith(audioQuality: s.first),
                              );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Default source
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.source_outlined),
                  title: const Text('Default Source'),
                  trailing: DropdownButton<String>(
                    value: settings.defaultSource,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(
                        value: 'ytmusic',
                        child: Text('YouTube Music'),
                      ),
                      DropdownMenuItem(
                        value: 'youtube',
                        child: Text('YouTube'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(downloadSettingsProvider.notifier)
                            .saveSettings(settings.copyWith(defaultSource: v));
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Download Manager Settings ──────────────────────────
              _SectionHeader(
                label: 'Download Manager',
                icon: Icons.tune_outlined,
              ),
              const SizedBox(height: 8),

              _NumericTile(
                label: 'Max Concurrent Downloads',
                value: settings.maxConcurrent,
                min: 1,
                max: 8,
                onChanged: (v) => ref
                    .read(downloadSettingsProvider.notifier)
                    .saveSettings(settings.copyWith(maxConcurrent: v)),
              ),
              const SizedBox(height: 8),

              _NumericTile(
                label: 'Max Retry Limit',
                value: settings.maxRetries,
                min: 0,
                max: 10,
                onChanged: (v) => ref
                    .read(downloadSettingsProvider.notifier)
                    .saveSettings(settings.copyWith(maxRetries: v)),
              ),
              const SizedBox(height: 8),

              _NumericTile(
                label: 'Connection Timeout (seconds)',
                value: settings.connectionTimeout,
                min: 5,
                max: 120,
                onChanged: (v) => ref
                    .read(downloadSettingsProvider.notifier)
                    .saveSettings(settings.copyWith(connectionTimeout: v)),
              ),
              const SizedBox(height: 8),

              _NumericTile(
                label: 'Segments per Download',
                value: settings.fragmentsPerDownload,
                min: 1,
                max: 16,
                onChanged: (v) => ref
                    .read(downloadSettingsProvider.notifier)
                    .saveSettings(settings.copyWith(fragmentsPerDownload: v)),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).hintColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PathTile extends StatelessWidget {
  const _PathTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onPick,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          subtitle.isEmpty ? 'Not set' : subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(onPressed: onPick, child: const Text('Browse')),
      ),
    );
  }
}

class _NumericTile extends StatelessWidget {
  const _NumericTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
