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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Library Paths',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            ResonanceButton(
              onPressed: () async {
                await ref.read(libraryProvider.notifier).resetToDefaults();
              },
              icon: UIcons.regular.undo_alt,
              label: 'Reset to Defaults',
              style: ResonanceButtonStyle.secondary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPathTile(
          context,
          icon: UIcons.regular.headphones,
          title: 'Music Library',
          path: libraryState.musicFolderPath,
          onEdit: () async {
            if (await PermissionService.requestStoragePermission()) {
              String? selected = await FilePicker.platform.getDirectoryPath();
              if (selected != null) libraryLogic.setMusicFolder(selected);
            }
          },
        ),
        const SizedBox(height: 12),
        _buildPathTile(
          context,
          icon: UIcons.regular.microphone,
          title: 'Lyrics Library',
          path: libraryState.lyricsFolderPath,
          onEdit: () async {
            if (await PermissionService.requestStoragePermission()) {
              String? selected = await FilePicker.platform.getDirectoryPath();
              if (selected != null) libraryLogic.setLyricsFolder(selected);
            }
          },
        ),
        const SizedBox(height: 12),
        _buildPathTile(
          context,
          icon: UIcons.regular.refresh,
          title: 'Cache Directory',
          path: libraryState.cacheFolderPath ?? 
                (Platform.isWindows ? 'Default (%LocalAppData%\\ChronoTech\\Resonance\\cache)' : 'Default (Internal App Storage)'),
          trailingIcon: UIcons.regular.pencil,
          onEdit: () async {
            if (await PermissionService.requestStoragePermission()) {
              String? selected = await FilePicker.platform.getDirectoryPath();
              if (selected != null) libraryLogic.setCacheFolder(selected);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPathTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? path,
    required VoidCallback onEdit,
    IconData? trailingIcon,
  }) {
    return ListTile(
      leading: Icon(icon, size: 18),
      title: Text(title),
      subtitle: Text(path ?? 'Not configured'),
      trailing: ReusableHoverIconButton(
        icon: trailingIcon ?? UIcons.regular.angle_small_right,
        tooltip: 'Edit $title',
        onTap: onEdit,
        iconSize: 18,
      ),
      tileColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
