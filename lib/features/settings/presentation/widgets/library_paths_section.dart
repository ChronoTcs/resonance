import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../library/application/library_provider.dart';
import '../../../../core/application/services/permission_service.dart';
import 'package:resonance_app/core/widgets/reusable_hover_icon_button.dart';
// import 'package:resonance_app/core/widgets/hover_widgets.dart'; // Unused

class LibraryPathsSection extends ConsumerWidget {
  const LibraryPathsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryLogic = ref.read(libraryProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Library Paths',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildPathTile(
          context,
          icon: Icons.library_music,
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
          icon: Icons.video_library,
          title: 'Video Library',
          path: libraryState.videoFolderPath,
          onEdit: () async {
            if (await PermissionService.requestStoragePermission()) {
              String? selected = await FilePicker.platform.getDirectoryPath();
              if (selected != null) libraryLogic.setVideoFolder(selected);
            }
          },
        ),
        const SizedBox(height: 12),
        _buildPathTile(
          context,
          icon: Icons.lyrics,
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
          icon: Icons.cached,
          title: 'Cache Directory',
          path: libraryState.cacheFolderPath ?? 
                (Platform.isWindows ? 'Default (%USERPROFILE%\\resonance_cache)' : 'Default (Internal App Storage)'),
          iconWidget: const Icon(Icons.edit),
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
    Widget? iconWidget,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(path ?? 'Not configured'),
      trailing: ReusableHoverIconButton(
        icon: iconWidget is Icon ? iconWidget.icon : Icons.chevron_right,
        tooltip: 'Edit $title',
        onTap: onEdit,
        iconSize: 20,
      ),
      tileColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
