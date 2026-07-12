import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/application/services/music_restore_service.dart';
import '../providers/package_info_provider.dart';

class AboutCard extends ConsumerStatefulWidget {
  const AboutCard({super.key});

  @override
  ConsumerState<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends ConsumerState<AboutCard> {
  int _tapCount = 0;
  bool _showRestore = false;

  void _handleTap() {
    setState(() {
      _tapCount++;
      if (_tapCount == 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('5 tap more to open the secret protocol...'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (_tapCount >= 10 && !_showRestore) {
        _showRestore = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore Protocol: Restricted Access Granted.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _handleRestore() async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Protocol'),
        content: const Text('Choose your music backup source:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'android'),
            child: const Text('Android (Internal)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'windows'),
            child: const Text('Windows (USB/OTG)'),
          ),
        ],
      ),
    );

    if (source == null) return;

    String? selectedDirectory;
    if (source == 'windows') {
      selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;
    }
    
    if (!mounted) return;
    
    // Tampilkan progress dialog (Penanda sistem sedang bekerja)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restore Protocol...'),
                SizedBox(height: 8),
                Text(
                  'Scanning & syncing metadata...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // On Android, passing null triggers Auto-Detection
      await ref.read(musicRestoreServiceProvider).restoreFromSource(selectedDirectory);
      
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore Protocol: SUCCESS. Metadata & Media re-synced.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      
      // Failure Notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Protocol Failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(packageInfoProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            leading: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: const DecorationImage(
                  image: AssetImage('assets/icons/app_icon.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            title: Text(
              'Resonance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '© 2026 ChronoTech. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                packageInfo.when(
                  data: (info) => Text(
                    'Version ${info.version}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const Text('v?.?.?'),
                ),
                const SizedBox(width: 8),
                Icon(UIcons.regular.angle_small_down, size: 20),
              ],
            ),
            children: [
              const Divider(height: 1),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _handleTap,
                            child: Text(
                              'An alternative, cross-platform media player',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        if (_showRestore)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: TextButton.icon(
                              onPressed: _handleRestore,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                foregroundColor: theme.primaryColor,
                                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              icon: Icon(UIcons.regular.rotate_right, size: 16),
                              label: const Text(
                                'Restore music',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLink(context, 'Licence Terms'),
                    _buildLink(context, 'Privacy Policy'),
                    _buildLink(context, 'Third-Party Software Acknowledgements'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLink(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          // Future implementation for links
        },
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
