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
import '../presentation/widgets/import_playlist_sheet.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

class PlaylistIOHelper {
  static void importPlaylist(BuildContext context, WidgetRef ref) {
    ImportPlaylistSheet.show(context);
  }

  static Future<void> importJsonFileDirectly(BuildContext context, WidgetRef ref) async {
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

      ref.read(notificationProvider.notifier).showNotification(
        'Playlist Imported',
        'Playlist imported successfully!',
        target: 'target:playlists',
        silentOsNotification: true,
      );
    } catch (e) {
      ref.read(notificationProvider.notifier).showNotification(
        'Import Failed',
        'Failed to import playlist: $e',
        isError: true,
        silentOsNotification: true,
      );
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

      ref.read(notificationProvider.notifier).showNotification(
        'Playlist Exported',
        'Successfully exported to ${p.basename(file.path)}',
        silentOsNotification: true,
      );
    } catch (e) {
      ref.read(notificationProvider.notifier).showNotification(
        'Export Failed',
        'Failed to export playlist: $e',
        isError: true,
        silentOsNotification: true,
      );
    }
  }

  static void renamePlaylistDialog(
    BuildContext context,
    WidgetRef? ref,
    Playlist playlist,
  ) {
    final ctrl = TextEditingController(text: playlist.name);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (context, dialogRef, _) => Dialog(
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
                      dialogRef.read(playlistProvider.notifier).renamePlaylist(playlist.id, v.trim());
                      Navigator.pop(dialogCtx);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ResonanceButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      label: 'Cancel',
                      style: ResonanceButtonStyle.secondary,
                    ),
                    const SizedBox(width: 12),
                    ResonanceButton(
                      onPressed: () {
                        if (ctrl.text.trim().isNotEmpty) {
                          dialogRef
                              .read(playlistProvider.notifier)
                              .renamePlaylist(playlist.id, ctrl.text.trim());
                          Navigator.pop(dialogCtx);
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
      ),
    );
  }

  static void deletePlaylistDialog(
    BuildContext context,
    WidgetRef? ref,
    Playlist playlist, {
    VoidCallback? onDeleteSuccess,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (context, dialogRef, _) => ResonanceConfirmDialog(
          title: 'Delete Playlist',
          content: 'Are you sure you want to delete "${playlist.name}"? This cannot be undone.',
          confirmLabel: 'Delete',
          isDanger: true,
          onConfirm: () {
            dialogRef.read(playlistProvider.notifier).deletePlaylist(playlist.id);
            if (onDeleteSuccess != null) {
              onDeleteSuccess();
            }
          },
        ),
      ),
    );
  }
}
