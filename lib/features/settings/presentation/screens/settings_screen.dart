import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../library/data/repositories/library_provider.dart';
import '../../../player/data/repositories/audio_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryLogic = ref.read(libraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'App & Appearance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('App Theme'),
            subtitle: const Text('Select visual mode'),
            trailing: Consumer(
              builder: (context, ref, _) {
                final themeMode = ref.watch(themeProvider);
                return DropdownButton<ThemeMode>(
                  value: themeMode,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  focusColor: Colors.transparent, // Fix boxy hover
                  underline: const SizedBox(), // remove standard underline
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System Default'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light (Cream)'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark (Monochrome)'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeProvider.notifier).setTheme(mode);
                    }
                  },
                );
              },
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hoverColor: Colors.white.withOpacity(
              0.05,
            ), // Smoother hover for the tile itself
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Accent colour'),
            subtitle: const Text('Select primary accent'),
            trailing: Consumer(
              builder: (context, ref, _) {
                final accentColor = ref.watch(accentColorProvider);
                return DropdownButton<Color?>(
                  value: accentColor,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  focusColor: Colors.transparent,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('System setting'),
                    ),
                    DropdownMenuItem(value: Colors.red, child: Text('Red')),
                    DropdownMenuItem(value: Colors.blue, child: Text('Blue')),
                    DropdownMenuItem(value: Colors.green, child: Text('Green')),
                    DropdownMenuItem(
                      value: Colors.orange,
                      child: Text('Orange'),
                    ),
                    DropdownMenuItem(
                      value: Colors.purple,
                      child: Text('Purple'),
                    ),
                  ],
                  onChanged: (color) {
                    ref
                        .read(accentColorProvider.notifier)
                        .setAccentColor(color);
                  },
                );
              },
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hoverColor: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 32),
          const Text(
            'Library Paths',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('Music Library'),
            subtitle: Text(libraryState.musicFolderPath ?? 'Not configured'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () async {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                libraryLogic.setMusicFolder(selectedDirectory);
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Video Library'),
            subtitle: Text(libraryState.videoFolderPath ?? 'Not configured'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () async {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                libraryLogic.setVideoFolder(selectedDirectory);
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.lyrics),
            title: const Text('Lyrics Library'),
            subtitle: Text(libraryState.lyricsFolderPath ?? 'Not configured'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () async {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                libraryLogic.setLyricsFolder(selectedDirectory);
              }
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Audio Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Volume
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final audioState = ref.watch(audioProvider);
                final audioNotifier = ref.read(audioProvider.notifier);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volume (${audioState.volume.toInt()}%)'),
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_mute,
                          size: 20,
                          color: Colors.grey,
                        ),
                        Expanded(
                          child: Slider(
                            value: audioState.volume,
                            min: 0,
                            max: 100,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) => audioNotifier.setVolume(val),
                          ),
                        ),
                        const Icon(
                          Icons.volume_up,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Playback Speed
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final audioState = ref.watch(audioProvider);
                final audioNotifier = ref.read(audioProvider.notifier);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playback Speed (${audioState.speed.toStringAsFixed(1)}x)',
                    ),
                    Row(
                      children: [
                        const Text(
                          '0.5x',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: audioState.speed,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) => audioNotifier.setSpeed(val),
                          ),
                        ),
                        const Text(
                          '2.0x',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Pitch
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final audioState = ref.watch(audioProvider);
                final audioNotifier = ref.read(audioProvider.notifier);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pitch (${audioState.pitch > 0 ? '+' : ''}${audioState.pitch.toStringAsFixed(1)})',
                    ),
                    Row(
                      children: [
                        const Text(
                          '-12',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: audioState.pitch,
                            min: -12.0,
                            max: 12.0,
                            divisions: 24,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) => audioNotifier.setPitch(val),
                          ),
                        ),
                        const Text(
                          '+12',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              return Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(audioProvider.notifier).restoreToDefault();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audio settings restored to default.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore Audio Defaults'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
