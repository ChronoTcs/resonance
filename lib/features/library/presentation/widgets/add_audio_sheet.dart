import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/presentation/widgets/morphing_library_bar.dart';

/// Modern floating inset bottom sheet for adding audio to the local library.
/// Supports drag-and-drop file ingestion, device explorer picking (Windows & Android),
/// direct navigation to the Explore page, and the Downloads manager shortcut.
class AddAudioSheet extends ConsumerStatefulWidget {
  const AddAudioSheet({super.key});

  /// Displays the modern floating bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const AddAudioSheet(),
    );
  }

  @override
  ConsumerState<AddAudioSheet> createState() => _AddAudioSheetState();
}

class _AddAudioSheetState extends ConsumerState<AddAudioSheet> {
  bool _isDragging = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _supportedExtensions = [
    'mp3',
    'm4a',
    'wav',
    'flac',
    'ogg',
    'opus',
    'aac',
    'wma',
  ];

  Future<void> _handleDroppedFiles(List<String> paths) async {
    final validPaths = paths.where((path) {
      final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
      return _supportedExtensions.contains(ext);
    }).toList();

    if (validPaths.isEmpty) {
      setState(() {
        _errorMessage = 'No supported audio files found (.mp3, .m4a, .flac, .wav, .ogg, .opus, .aac)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final count = await ref.read(libraryProvider.notifier).importAudioPaths(
      validPaths,
      context: mounted ? context : null,
    );

    if (mounted) {
      if (count > 0) {
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAudioFiles() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        allowMultiple: true,
        dialogTitle: 'Select Audio Files to Add to Library',
      );

      if (result == null || result.paths.isEmpty) return;

      final validPaths = result.paths.whereType<String>().toList();
      if (validPaths.isEmpty) return;
      if (!mounted) return;

      setState(() => _isLoading = true);

      final count = await ref.read(libraryProvider.notifier).importAudioPaths(
        validPaths,
        context: mounted ? context : null,
      );

      if (mounted) {
        if (count > 0) {
          Navigator.pop(context);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to select files: $e';
        });
      }
    }
  }

  void _goToExplore() {
    Navigator.pop(context);
    ref.read(mainNavigationProvider.notifier).setIndex(1);
  }

  void _goToDownloads() {
    final bool isDesktop = AppBreakpoints.isWide(context);
    Navigator.pop(context);
    if (isDesktop) {
      ref.read(mainNavigationProvider.notifier).setIndex(4);
    } else {
      ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.downloads);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingSheetShell(
      title: 'Add Audio to Library',
      icon: UIcons.regular.music,
      onClose: _isLoading ? null : () => Navigator.pop(context),
      children: [
        _AudioFileDropCard(
          isDragging: _isDragging,
          isLoading: _isLoading,
          onDragEntered: () => setState(() => _isDragging = true),
          onDragExited: () => setState(() => _isDragging = false),
          onFilesDropped: (paths) {
            setState(() => _isDragging = false);
            _handleDroppedFiles(paths);
          },
          onPickFiles: _pickAudioFiles,
        ),
        const SizedBox(height: 14),
        const _SheetDivider(label: 'OR DISCOVER ONLINE'),
        const SizedBox(height: 14),
        _ExploreShortcutCard(
          onTap: _isLoading ? null : _goToExplore,
        ),
        const SizedBox(height: 10),
        _DownloadsShortcutCard(
          onTap: _isLoading ? null : _goToDownloads,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _SheetErrorBanner(message: _errorMessage!),
        ],
      ],
    );
  }
}

// ── Atomic Sub-Widgets (Zero Pyramid Nesting) ──

class _AudioFileDropCard extends StatelessWidget {
  final bool isDragging;
  final bool isLoading;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final ValueChanged<List<String>> onFilesDropped;
  final VoidCallback onPickFiles;

  const _AudioFileDropCard({
    required this.isDragging,
    required this.isLoading,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onFilesDropped,
    required this.onPickFiles,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPickFiles,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: isDragging
                  ? primary.withValues(alpha: 0.12)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDragging
                    ? primary
                    : colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
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
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Extracting audio metadata & artwork...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ] else ...[
                  Icon(
                    UIcons.regular.folder_upload,
                    size: 32,
                    color: isDragging ? primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Drag & drop audio files here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDragging ? primary : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'or click to browse from device storage / file explorer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MP3, FLAC, M4A, WAV, OGG, OPUS, AAC',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreShortcutCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _ExploreShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  UIcons.regular.compass_alt,
                  color: primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover on Explore',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stream songs, search trending charts & mood playlists',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                UIcons.regular.angle_small_right,
                size: 18,
                color: theme.hintColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadsShortcutCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _DownloadsShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  UIcons.regular.download,
                  color: colorScheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Go to Downloads',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View offline downloaded songs and download queue',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                UIcons.regular.angle_small_right,
                size: 18,
                color: theme.hintColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  final String label;

  const _SheetDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Divider(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ],
    );
  }
}

class _SheetErrorBanner extends StatelessWidget {
  final String message;

  const _SheetErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            UIcons.regular.cross_circle,
            size: 14,
            color: colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
