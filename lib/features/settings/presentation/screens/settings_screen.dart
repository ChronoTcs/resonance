import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../library/application/library_provider.dart';
import '../../../player/application/audio_provider.dart';
import '../../application/maintenance_provider.dart';
import 'package:resonance_app/core/widgets/hover_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/about_card.dart';
import './help_screen.dart';
import '../../application/update_provider.dart';
import '../../../lyrics/application/lyrics_translation_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }

    // Fallback to older storage permission if manageExternalStorage isn't supported
    if (!status.isGranted) {
      var readStatus = await Permission.storage.status;
      if (!readStatus.isGranted) {
        readStatus = await Permission.storage.request();
      }
      return readStatus.isGranted;
    }

    return status.isGranted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryLogic = ref.read(libraryProvider.notifier);

    final theme = Theme.of(context);
    return Scaffold(
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ─── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Settings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'App & Appearance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeSetting(context, ref),
          const SizedBox(height: 12),
          _buildAccentSetting(context, ref),
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
            trailing: ModernIconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () async {
                if (await _requestStoragePermission()) {
                  String? selectedDirectory = await FilePicker.platform
                      .getDirectoryPath();
                  if (selectedDirectory != null) {
                    libraryLogic.setMusicFolder(selectedDirectory);
                  }
                }
              },
              iconSize: 20,
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Video Library'),
            subtitle: Text(libraryState.videoFolderPath ?? 'Not configured'),
            trailing: ModernIconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () async {
                if (await _requestStoragePermission()) {
                  String? selectedDirectory = await FilePicker.platform
                      .getDirectoryPath();
                  if (selectedDirectory != null) {
                    libraryLogic.setVideoFolder(selectedDirectory);
                  }
                }
              },
              iconSize: 20,
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.lyrics),
            title: const Text('Lyrics Library'),
            subtitle: Text(libraryState.lyricsFolderPath ?? 'Not configured'),
            trailing: ModernIconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () async {
                if (await _requestStoragePermission()) {
                  String? selectedDirectory = await FilePicker.platform
                      .getDirectoryPath();
                  if (selectedDirectory != null) {
                    libraryLogic.setLyricsFolder(selectedDirectory);
                  }
                }
              },
              iconSize: 20,
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.cached),
            title: const Text('Cache Directory'),
            subtitle: Text(
              libraryState.cacheFolderPath ??
                  (Platform.isWindows
                      ? 'Default (%USERPROFILE%\\resonance_cache)'
                      : 'Default (Internal App Storage)'),
            ),
            trailing: ModernIconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                if (await _requestStoragePermission()) {
                  String? selectedDirectory = await FilePicker.platform
                      .getDirectoryPath();
                  if (selectedDirectory != null) {
                    libraryLogic.setCacheFolder(selectedDirectory);
                  }
                }
              },
              iconSize: 20,
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
                child: HoverWrapper(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ref.read(audioProvider.notifier).restoreToDefault();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audio settings restored to default.'),
                      ),
                    );
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restore),
                      const SizedBox(width: 8),
                      const Text('Restore Audio Defaults'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Lyrics Translation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _buildTranslationSetting(context, ref),
          const SizedBox(height: 32),
          const Text(
            'Network & Data Usage',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final maintenance = ref.watch(maintenanceProvider);
                final notifier = ref.read(maintenanceProvider.notifier);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.data_usage),
                  title: const Text('Total Data Used'),
                  subtitle: Text(
                    notifier.formatBytes(maintenance.totalDataUsage),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset Usage?'),
                          content: const Text(
                            'This will reset the total data usage counter to zero.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Reset',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await notifier.resetDataUsage();
                      }
                    },
                    child: const Text('Reset'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Cache Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final maintenance = ref.watch(maintenanceProvider);
                final notifier = ref.read(maintenanceProvider.notifier);

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storage),
                      title: const Text('Local Cache Size'),
                      subtitle: Text(maintenance.cacheSize),
                      trailing: ModernIconButton(
                        icon: const Icon(
                          Icons.delete_sweep,
                          color: Colors.redAccent,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Clear Cache?'),
                              content: const Text(
                                'This will delete all cached audio, lyrics, and metadata.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await notifier.clearCache();
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const AboutCard(),
          _buildNavigationItem(
            context,
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            subtitle: 'Get help and read guides',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpScreen()),
            ),
          ),
          _buildDropdownItem(
            context,
            icon: Icons.favorite_border,
            title: 'Support Me',
            subtitle: 'Report bugs or buy me a coffee',
            children: [
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.orange),
                title: const Text('Report a Bug'),
                subtitle: const Text('Open an issue on GitHub'),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/ChronoTechs/resonance/issues'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.coffee, color: Colors.brown),
                title: const Text('Buy me a Coffee'),
                subtitle: const Text('Support development with a donation'),
                onTap: () => _handleDonation(context),
              ),
            ],
          ),
          _buildNavigationItem(
            context,
            icon: Icons.system_update_alt,
            title: 'Check for Updates',
            subtitle: 'Check if a newer version is available',
            onTap: () => _handleUpdateCheck(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDropdownItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            leading: Icon(icon, color: theme.primaryColor),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: ListTile(
          leading: Icon(icon, color: theme.primaryColor),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _handleDonation(BuildContext context) async {
    const String fallbackUrl = 'https://linktr.ee/Chronosz';
    const String configUrl = 'https://raw.githubusercontent.com/ChronoTechs/resonance/refs/heads/main/app_config.json';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting...'), duration: Duration(seconds: 2)),
    );

    try {
      final response = await http.get(Uri.parse(configUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final donateUrl = data['donate_url'] as String?;
        
        if (donateUrl != null && await canLaunchUrl(Uri.parse(donateUrl))) {
          await launchUrl(Uri.parse(donateUrl), mode: LaunchMode.externalApplication);
          return;
        }
      }
      // If we reach here, either statusCode != 200 or donate_url was missing/invalid
      throw Exception('Could not fetch remote config');
    } catch (e) {
      // Fallback
      if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open donation link.')),
          );
        }
      }
    }
  }

  Future<void> _handleUpdateCheck(BuildContext context, WidgetRef ref) async {
    final updateNotifier = ref.read(updateProvider.notifier);
    
    // First call to check
    await updateNotifier.checkForUpdate();
    
    if (!context.mounted) return;
    _showUpdateDialog(context, ref);
  }

  void _showUpdateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(updateProvider);
            final notifier = ref.read(updateProvider.notifier);

            return AlertDialog(
              title: Text(state.isChecking 
                ? 'Checking for Updates...' 
                : state.isDownloading 
                  ? 'Downloading Update...' 
                  : state.updateAvailable 
                    ? 'New version available: v${state.latestVersion}' 
                    : 'Up to Date'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.isChecking)
                    const Center(child: CircularProgressIndicator())
                  else if (state.isDownloading)
                    Column(
                      children: [
                        const Text('Please wait while we prepare the installer...'),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: state.downloadProgress),
                        const SizedBox(height: 8),
                        Text('${(state.downloadProgress * 100).toInt()}%', 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  else if (state.updateAvailable)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Changelog:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(state.changelog),
                            if (Platform.isWindows) ...[
                              const SizedBox(height: 16),
                              const Text('Note: The application will close and the installer will start automatically.',
                                style: TextStyle(color: Colors.orange, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    )
                  else if (state.error != null)
                    Text('Error: ${state.error}', style: const TextStyle(color: Colors.red))
                  else
                    const Text('Resonance is already at the latest version!'),
                ],
              ),
              actions: [
                if (!state.isChecking && !state.isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                if (state.updateAvailable && !state.isDownloading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (state.downloadProgress < 1.0) {
                        await notifier.downloadUpdate();
                      }
                      // If download finished or was already finished, trigger install
                      if (context.mounted) {
                        await notifier.installUpdate(context);
                      }
                    },
                    child: Text(state.downloadProgress < 1.0 ? 'Download & Install' : 'Install Now'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeSetting(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return _buildSettingItem(
      context,
      icon: Icons.palette,
      title: 'App Theme',
      subtitle: 'Select visual mode',
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        dropdownColor: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        focusColor: Colors.transparent,
        underline: const SizedBox(),
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
          if (mode != null) ref.read(themeProvider.notifier).setTheme(mode);
        },
      ),
    );
  }

  Widget _buildAccentSetting(BuildContext context, WidgetRef ref) {
    final accentMode = ref.watch(accentColorProvider);
    return _buildSettingItem(
      context,
      icon: Icons.color_lens,
      title: 'Accent colour',
      subtitle: 'Select primary accent',
      trailing: DropdownButton<String?>(
        value: accentMode,
        dropdownColor: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        focusColor: Colors.transparent,
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem(value: null, child: Text('System setting')),
          const DropdownMenuItem(
            value: 'windows',
            child: Text('Windows Accent'),
          ),
          const DropdownMenuItem(value: 'cream', child: Text('Soft Cream')),
          DropdownMenuItem(
            value: '0x${Colors.red.value.toRadixString(16)}',
            child: const Text('Red'),
          ),
          DropdownMenuItem(
            value: '0x${Colors.blue.value.toRadixString(16)}',
            child: const Text('Blue'),
          ),
          DropdownMenuItem(
            value: '0x${Colors.green.value.toRadixString(16)}',
            child: const Text('Green'),
          ),
          DropdownMenuItem(
            value: '0x${Colors.orange.value.toRadixString(16)}',
            child: const Text('Orange'),
          ),
          DropdownMenuItem(
            value: '0x${Colors.purple.value.toRadixString(16)}',
            child: const Text('Purple'),
          ),
        ],
        onChanged: (mode) =>
            ref.read(accentColorProvider.notifier).setAccentColor(mode),
      ),
    );
  }

  Widget _buildTranslationSetting(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(lyricsTranslationProvider);
    final translationNotifier = ref.read(lyricsTranslationProvider.notifier);

    final Map<String, String> languages = {
      'id': 'Indonesian',
      'en': 'English',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh-cn': 'Chinese (Simplified)',
      'zh-tw': 'Chinese (Traditional)',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'ru': 'Russian',
      'ar': 'Arabic',
      'pt': 'Portuguese',
      'it': 'Italian',
      'vi': 'Vietnamese',
      'th': 'Thai',
    };

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('Show Translation Button'),
          subtitle: const Text('Show a button to translate lyrics in the player'),
          trailing: Switch(
            value: translationState.isSystemEnabled,
            onChanged: (val) => translationNotifier.toggleSystemEnabled(),
            activeColor: Theme.of(context).primaryColor,
          ),
          tileColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          context,
          icon: Icons.language,
          title: 'Target Language',
          subtitle: 'Select language to translate to',
          trailing: DropdownButton<String>(
            value: translationState.targetLanguage,
            dropdownColor: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox(),
            items: languages.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: (lang) {
              if (lang != null) translationNotifier.setTargetLanguage(lang);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: ButtonTheme(alignedDropdown: true, child: trailing),
              ),
            ),
          ],
        ),
      );
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(child: trailing),
      ),
      tileColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
