import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/about_card.dart';
import '../screens/help_screen.dart';
import '../../application/update_provider.dart';
import '../../data/repositories/support_repository.dart';
import 'settings_widgets.dart';

class SupportUpdateSection extends ConsumerWidget {
  const SupportUpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onTap: () => _handleDonation(context, ref),
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
      ],
    );
  }

  Widget _buildDropdownItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SettingsDropdownTile(icon: icon, title: title, subtitle: subtitle, children: children);
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
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: ListTile(
          leading: Icon(icon, color: theme.primaryColor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _handleDonation(BuildContext context, WidgetRef ref) async {
    const String fallbackUrl = 'https://linktr.ee/Chronosz';
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting...'), duration: Duration(seconds: 2)),
    );

    try {
      final donateUrl = await ref.read(supportRepositoryProvider).getDonateUrl();
      if (donateUrl != null && await canLaunchUrl(Uri.parse(donateUrl))) {
        await launchUrl(Uri.parse(donateUrl), mode: LaunchMode.externalApplication);
        return;
      }
      throw Exception('Could not fetch donate url');
    } catch (e) {
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
                  if (state.isChecking) const Center(child: CircularProgressIndicator())
                  else if (state.isDownloading)
                    Column(
                      children: [
                        const Text('Please wait while we prepare the installer...'),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: state.downloadProgress),
                        const SizedBox(height: 8),
                        Text('${(state.downloadProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  else const Text('Resonance is already at the latest version!'),
                ],
              ),
              actions: [
                if (!state.isChecking && !state.isDownloading)
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                if (state.updateAvailable && !state.isDownloading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (state.downloadProgress < 1.0) await notifier.downloadUpdate();
                      if (context.mounted) await notifier.installUpdate(context);
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
}
