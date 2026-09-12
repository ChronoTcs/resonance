import 'package:resonance/core/widgets/widgets.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:resonance/core/utils/uicons.dart';

import '../../../library/application/library_provider.dart';
import '../../../../core/application/services/permission_service.dart';

class LibraryPathsSection extends ConsumerWidget {
  const LibraryPathsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryLogic = ref.read(libraryProvider.notifier);
    final isWindows = Platform.isWindows;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Library Paths',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            if (isWindows)
              ResonanceButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dlg) => ResonanceConfirmDialog(
                      title: 'Reset Library Paths',
                      content: 'Reset all library folder paths to factory defaults?',
                      confirmLabel: 'Reset',
                      onConfirm: () async {
                        await ref.read(libraryProvider.notifier).resetToDefaults();
                      },
                    ),
                  );
                },
                icon: UIcons.regular.undo_alt,
                label: 'Reset to Defaults',
                style: ResonanceButtonStyle.secondary,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Grouped Library Paths Card Container
        Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _buildPathTile(
                context,
                icon: UIcons.regular.headphones,
                title: 'Local Music Storage',
                path: isWindows
                    ? libraryState.musicFolderPath
                    : 'Internal Storage (App Sandbox)',
                trailingIcon: isWindows ? UIcons.regular.pencil : UIcons.regular.lock,
                tooltip: isWindows ? 'Edit Local Music Folder' : 'Locked to Android App Sandbox',
                onEdit: isWindows
                    ? () async {
                        if (await PermissionService.requestStoragePermission()) {
                          String? selected = await FilePicker.platform.getDirectoryPath();
                          if (selected != null) libraryLogic.setMusicFolder(selected);
                        }
                      }
                    : null,
              ),
              const Divider(height: 1),
              _buildPathTile(
                context,
                icon: UIcons.regular.cloud_download,
                title: 'Stream Music Cache',
                path: isWindows
                    ? (libraryState.streamFolderPath ?? r'%LOCALAPPDATA%\ChronoTech\Resonance\stream')
                    : 'Internal Cache (context.cacheDir/stream)',
                trailingIcon: isWindows ? UIcons.regular.pencil : UIcons.regular.lock,
                tooltip: isWindows ? 'Edit Stream Cache Folder' : 'Managed by Android Cache Evictor',
                onEdit: isWindows
                    ? () async {
                        if (await PermissionService.requestStoragePermission()) {
                          String? selected = await FilePicker.platform.getDirectoryPath();
                          if (selected != null) libraryLogic.setStreamFolder(selected);
                        }
                      }
                    : null,
              ),
              const Divider(height: 1),
              _buildPathTile(
                context,
                icon: UIcons.regular.hdd,
                title: 'System App Cache',
                path: isWindows
                    ? (libraryState.cacheFolderPath ?? r'%LOCALAPPDATA%\ChronoTech\Resonance\cache')
                    : 'Internal Cache (context.cacheDir/cache)',
                trailingIcon: isWindows ? UIcons.regular.pencil : UIcons.regular.lock,
                tooltip: isWindows ? 'Edit System App Cache Folder' : 'Managed by Android OS',
                onEdit: isWindows
                    ? () async {
                        if (await PermissionService.requestStoragePermission()) {
                          String? selected = await FilePicker.platform.getDirectoryPath();
                          if (selected != null) libraryLogic.setCacheFolder(selected);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
        if (!isWindows) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(UIcons.regular.info, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Storage paths on Android are managed by OS sandboxing. Use Cache Management below to delete or clear cached items.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPathTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? path,
    VoidCallback? onEdit,
    IconData? trailingIcon,
    String? tooltip,
  }) {
    return ListTile(
      leading: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(path ?? 'Not configured'),
      trailing: trailingIcon != null
          ? (onEdit != null
              ? ReusableHoverIconButton(
                  icon: trailingIcon,
                  tooltip: tooltip ?? title,
                  onTap: onEdit,
                  iconSize: 18,
                )
              : Tooltip(
                  message: tooltip ?? title,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      trailingIcon,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ))
          : null,
    );
  }
}
