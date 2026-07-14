import 'package:resonance/core/widgets/widgets.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'playlist_provider.dart';
import '../data/models/playlist_model.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

class PlaylistIOHelper {
  static Future<void> importPlaylist(BuildContext context, WidgetRef ref) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return;

      final file = result.files.single;
      final filePath = file.path;
      final fileExtension = filePath != null ? p.extension(filePath).toLowerCase() : '';
      final fileName = file.name.toLowerCase();

      // Strict enforcement: MUST be a .json file
      if ((filePath != null && fileExtension != '.json') || (!fileName.endsWith('.json'))) {
        throw const FormatException('Selected file is not a valid JSON file.');
      }

      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (filePath != null) {
        final localFile = File(filePath);
        content = await localFile.readAsString();
      } else {
        throw const FileSystemException('Could not read the selected file content.');
      }
      
      await ref.read(playlistProvider.notifier).importPlaylist(content);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist imported successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import playlist: $e')),
        );
      }
    }
  }

  static Future<void> exportPlaylist(BuildContext context, WidgetRef ref, String playlistId, String playlistName) async {
    try {
      String? directoryPath;
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        directoryPath = directory.path;
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        directoryPath = directory.path;
      } else {
        directoryPath = await FilePicker.platform.getDirectoryPath();
      }
      if (directoryPath == null) return;
      
      final jsonString = await ref.read(playlistProvider.notifier).exportPlaylist(playlistId);
      if (jsonString == null) return;

      final safeName = playlistName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File(p.join(directoryPath, 'playlist_$safeName.json'));
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported to ${p.basename(file.path)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export playlist: $e')),
        );
      }
    }
  }

  static void renamePlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) {
    final ctrl = TextEditingController(text: playlist.name);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rename Playlist',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    ref.read(playlistProvider.notifier).renamePlaylist(playlist.id, v.trim());
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ResonanceButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Cancel',
                    style: ResonanceButtonStyle.secondary,
                  ),
                  const SizedBox(width: 12),
                  ResonanceButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        ref
                            .read(playlistProvider.notifier)
                            .renamePlaylist(playlist.id, ctrl.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    label: 'Save',
                    style: ResonanceButtonStyle.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void deletePlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist, {
    VoidCallback? onDeleteSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => ResonanceConfirmDialog(
        title: 'Delete Playlist',
        content: 'Are you sure you want to delete "${playlist.name}"? This cannot be undone.',
        confirmLabel: 'Delete',
        isDanger: true,
        onConfirm: () {
          ref.read(playlistProvider.notifier).deletePlaylist(playlist.id);
          if (onDeleteSuccess != null) {
            onDeleteSuccess();
          }
        },
      ),
    );
  }

  static List<ResonanceContextMenuItem> buildPlaylistMenuItems({
    required BuildContext context,
    required WidgetRef ref,
    required Playlist playlist,
    required bool isOnline,
    VoidCallback? onDeleteSuccess,
  }) {
    return [
      ResonanceContextMenuItem(
        icon: UIcons.regular.play,
        label: 'Play all',
        onTap: () {
          if (playlist.tracks.isNotEmpty) {
            ref.read(audioProvider.notifier).playPlaylist(playlist.tracks, initialIndex: 0);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This playlist has no tracks')),
            );
          }
        },
      ),
      ResonanceContextMenuItem(
        icon: UIcons.regular.edit,
        label: 'Rename',
        onTap: () => renamePlaylistDialog(context, ref, playlist),
      ),
      if (isOnline)
        ResonanceContextMenuItem(
          icon: UIcons.regular.upload,
          label: 'Export JSON',
          onTap: () => exportPlaylist(context, ref, playlist.id, playlist.name),
        ),
      ResonanceContextMenuItem(
        icon: AppIcons.trash,
        label: 'Delete',
        isDanger: true,
        onTap: () => deletePlaylistDialog(
          context,
          ref,
          playlist,
          onDeleteSuccess: onDeleteSuccess,
        ),
      ),
    ];
  }
}
