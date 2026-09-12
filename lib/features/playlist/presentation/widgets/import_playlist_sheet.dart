import 'dart:convert';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

/// Modern floating inset bottom sheet for importing playlists via YouTube link or JSON file.
class ImportPlaylistSheet extends ConsumerStatefulWidget {
  const ImportPlaylistSheet({super.key});

  /// Displays the floating modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const ImportPlaylistSheet(),
    );
  }

  @override
  ConsumerState<ImportPlaylistSheet> createState() => _ImportPlaylistSheetState();
}

class _ImportPlaylistSheetState extends ConsumerState<ImportPlaylistSheet> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isDragging = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _extractPlaylistId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('list')) {
      return uri.queryParameters['list'];
    }

    if (trimmed.startsWith('PL') ||
        trimmed.startsWith('VL') ||
        trimmed.startsWith('RD') ||
        trimmed.startsWith('OLAK') ||
        trimmed.startsWith('UU') ||
        trimmed.startsWith('FL') ||
        trimmed.startsWith('LL') ||
        trimmed.length >= 12) {
      return trimmed;
    }

    return null;
  }

  Future<void> _handleYouTubeImport() async {
    final rawInput = _urlController.text.trim();
    final playlistId = _extractPlaylistId(rawInput);

    if (playlistId == null || playlistId.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid YouTube or YouTube Music playlist link.');
      return;
    }

    final isOnline = ref.read(networkConnectivityProvider).isOnline;
    if (!isOnline) {
      setState(() => _errorMessage = 'Cannot import YouTube playlist while offline.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(youtubePlaylistRepositoryProvider);
      final tracks = await repo.fetchFullPlaylistContents(playlistId);

      if (tracks.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No tracks found. The playlist may be private or invalid.';
          });
        }
        return;
      }

      final customName = _nameController.text.trim();
      final playlistName = customName.isNotEmpty ? customName : 'Imported Playlist (${tracks.length} tracks)';

      final newId = await ref.read(playlistProvider.notifier).createPlaylist(playlistName);

      if (newId != null && mounted) {
        final mediaItems = tracks
            .map(
              (t) => MediaItem(
                id: t.id,
                title: t.title,
                artist: t.author,
                thumbnailUrl: t.thumbnailUrl,
                path: t.id,
                type: 'audio',
              ),
            )
            .toList();

        await ref.read(playlistProvider.notifier).addTracksToPlaylist(newId, mediaItems);

        if (mounted) {
          Navigator.pop(context);
          ref.read(notificationProvider.notifier).showNotification(
            'Playlist Imported',
            'Successfully imported "$playlistName" (${mediaItems.length} songs)!',
            target: 'target:playlist:$newId',
            silentOsNotification: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to import: $e';
        });
      }
    }
  }

  Future<void> _handleFileImport(String filePath) async {
    try {
      final file = File(filePath);
      final ext = p.extension(filePath).toLowerCase();
      if (ext != '.json') {
        setState(() => _errorMessage = 'Only .json playlist files are supported.');
        return;
      }

      final content = await file.readAsString();
      await ref.read(playlistProvider.notifier).importPlaylist(content);

      if (mounted) {
        Navigator.pop(context);
        ref.read(notificationProvider.notifier).showNotification(
          'Playlist Imported',
          'Playlist imported from ${p.basename(filePath)}!',
          target: 'target:playlists',
          silentOsNotification: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to import JSON: $e');
      }
    }
  }

  Future<void> _pickJsonFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final filePath = file.path;

      if (file.bytes != null) {
        final content = utf8.decode(file.bytes!);
        await ref.read(playlistProvider.notifier).importPlaylist(content);
        if (mounted) {
          Navigator.pop(context);
          ref.read(notificationProvider.notifier).showNotification(
            'Playlist Imported',
            'Playlist imported successfully!',
            target: 'target:playlists',
            silentOsNotification: true,
          );
        }
      } else if (filePath != null) {
        await _handleFileImport(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to pick/import file: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingSheetShell(
      title: 'Import Playlist',
      icon: UIcons.regular.cloud_download,
      onClose: _isLoading ? null : () => Navigator.pop(context),
      children: [
        _YouTubeLinkImportCard(
          urlController: _urlController,
          nameController: _nameController,
          isLoading: _isLoading,
          onImport: _handleYouTubeImport,
        ),
        const SizedBox(height: 16),
        const _SheetDivider(label: 'OR'),
        const SizedBox(height: 16),
        _JsonFileDropCard(
          isDragging: _isDragging,
          isLoading: _isLoading,
          onDragEntered: () => setState(() => _isDragging = true),
          onDragExited: () => setState(() => _isDragging = false),
          onFileDropped: (filePath) {
            setState(() => _isDragging = false);
            _handleFileImport(filePath);
          },
          onPickFile: _pickJsonFile,
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

class _YouTubeLinkImportCard extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController nameController;
  final bool isLoading;
  final VoidCallback onImport;

  const _YouTubeLinkImportCard({
    required this.urlController,
    required this.nameController,
    required this.isLoading,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YouTube / YouTube Music Link',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlController,
            enabled: !isLoading,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste playlist URL or ID',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                UIcons.regular.link,
                size: 16,
                color: primary.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: primary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            enabled: !isLoading,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Custom playlist title (Optional)',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                UIcons.regular.edit,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: primary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ResonanceButton(
              onPressed: isLoading ? null : onImport,
              icon: isLoading ? null : UIcons.regular.download,
              label: isLoading ? 'Extracting Songs...' : 'Import from YouTube',
              style: ResonanceButtonStyle.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonFileDropCard extends StatelessWidget {
  final bool isDragging;
  final bool isLoading;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final ValueChanged<String> onFileDropped;
  final VoidCallback onPickFile;

  const _JsonFileDropCard({
    required this.isDragging,
    required this.isLoading,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onFileDropped,
    required this.onPickFile,
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
        if (details.files.isNotEmpty) {
          final dropped = details.files.first;
          onFileDropped(dropped.path);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPickFile,
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
                Icon(
                  UIcons.regular.document,
                  size: 30,
                  color: isDragging ? primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag & drop a .json playlist file here',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDragging ? primary : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'or click to browse from File Explorer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
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
              color: theme.hintColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
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
