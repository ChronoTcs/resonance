import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

class ImportPlaylistDialog extends ConsumerStatefulWidget {
  final bool isStreamTab;
  const ImportPlaylistDialog({super.key, this.isStreamTab = true});

  @override
  ConsumerState<ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends ConsumerState<ImportPlaylistDialog> {
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

    // Direct playlist ID support
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

      final newId = await ref.read(playlistProvider.notifier).createPlaylist(
            playlistName,
            isStream: true,
          );

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported "$playlistName" (${mediaItems.length} songs)!'),
              behavior: SnackBarBehavior.floating,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playlist imported from ${p.basename(filePath)}!'),
            behavior: SnackBarBehavior.floating,
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playlist imported successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Icon(UIcons.regular.cloud_download, color: primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Import Playlist',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                ReusableHoverIconButton(
                  icon: UIcons.regular.cross,
                  tooltip: 'Close',
                  iconSize: 16.0,
                  onTap: _isLoading ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 1: YouTube Link Input
            Text(
              'Option 1: YouTube / YouTube Music Link',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              enabled: !_isLoading,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Paste YouTube / YouTube Music playlist URL or ID',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(UIcons.regular.link, size: 16, color: primary.withValues(alpha: 0.7)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: !_isLoading,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Custom playlist title (Optional)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(UIcons.regular.edit, size: 16, color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
            const SizedBox(height: 12),

            // Import YouTube Button
            Align(
              alignment: Alignment.centerRight,
              child: ResonanceButton(
                onPressed: _isLoading ? null : _handleYouTubeImport,
                icon: _isLoading ? null : UIcons.regular.download,
                label: _isLoading ? 'Extracting Songs...' : 'Import from YouTube',
                style: ResonanceButtonStyle.primary,
              ),
            ),

            const SizedBox(height: 16),
            // Divider with OR
            Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor.withValues(alpha: 0.15))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.dividerColor.withValues(alpha: 0.15))),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: Drag & Drop / Click to Pick JSON File
            Text(
              'Option 2: JSON Backup File',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                if (details.files.isNotEmpty) {
                  final dropped = details.files.first;
                  _handleFileImport(dropped.path);
                }
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _pickJsonFile,
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? primary.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDragging
                            ? primary
                            : theme.dividerColor.withValues(alpha: 0.2),
                        width: _isDragging ? 1.8 : 1.0,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          UIcons.regular.document,
                          size: 28,
                          color: _isDragging ? primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Drag & drop a .json playlist file here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _isDragging ? primary : theme.colorScheme.onSurface,
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
            ),

            // Error Message (if any)
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(UIcons.regular.cross_circle, size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
