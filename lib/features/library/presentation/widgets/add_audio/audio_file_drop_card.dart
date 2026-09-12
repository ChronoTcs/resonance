import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:resonance/core/constants/audio_constants.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'drop_zone_action_button.dart';

/// Desktop-tailored drag & drop zone for raw audio tracks or entire folders.
class AudioFileDropCard extends StatelessWidget {
  final bool isDragging;
  final bool isLoading;
  final int progressCurrent;
  final int progressTotal;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final ValueChanged<List<String>> onFilesDropped;
  final VoidCallback onPickFiles;
  final VoidCallback? onPickFolder;

  const AudioFileDropCard({
    super.key,
    required this.isDragging,
    required this.isLoading,
    required this.progressCurrent,
    required this.progressTotal,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onFilesDropped,
    required this.onPickFiles,
    this.onPickFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return DropTarget(
      onDragEntered: (_) => onDragEntered(),
      onDragExited: (_) => onDragExited(),
      onDragDone: (details) {
        final paths = details.files.map((f) => f.path).toList();
        onFilesDropped(paths);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: isDragging
              ? primary.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDragging
                ? primary
                : colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
            width: isDragging ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progressTotal > 0 ? (progressCurrent / progressTotal).clamp(0.0, 1.0) : null,
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                progressTotal > 0
                    ? 'Importing $progressCurrent of $progressTotal tracks...'
                    : 'Extracting audio metadata & artwork...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
              if (progressTotal > 0) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progressCurrent / progressTotal).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ),
              ],
            ] else ...[
              Icon(
                isDragging ? UIcons.regular.folder_upload : UIcons.regular.cloud_upload,
                size: 36,
                color: isDragging ? primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                'Drag & drop audio files or folders here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDragging ? primary : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Drop single tracks, albums, or entire music folders from File Explorer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  DropZoneActionButton(
                    icon: UIcons.regular.music,
                    label: 'Browse Files',
                    isPrimary: false,
                    onTap: isLoading ? null : onPickFiles,
                  ),
                  if (onPickFolder != null)
                    DropZoneActionButton(
                      icon: UIcons.regular.folder_upload,
                      label: 'Scan Folder',
                      isPrimary: true,
                      onTap: isLoading ? null : onPickFolder,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FILES & FOLDERS • ${AppAudioFormats.formatListLabel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: theme.hintColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
