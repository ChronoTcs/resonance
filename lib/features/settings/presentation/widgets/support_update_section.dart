import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/about_card.dart';
import '../screens/help_screen.dart';
import 'settings_widgets.dart';

class SupportUpdateSection extends ConsumerWidget {
  final VoidCallback? onOpenHelp;
  final VoidCallback? onOpenUpdates;

  const SupportUpdateSection({super.key, this.onOpenHelp, this.onOpenUpdates});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfig = ref.watch(appConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AboutCard(),
        _buildNavigationItem(
          context,
          icon: UIcons.regular.question,
          title: 'Help & FAQ',
          subtitle: 'Get help and read guides',
          onTap: () {
            if (onOpenHelp != null) {
              onOpenHelp!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            }
          },
        ),
        _buildDropdownItem(
          context,
          icon: UIcons.regular.heart,
          title: 'Support Me',
          subtitle: 'Report bugs or buy me a coffee',
          children: [
            ListTile(
              dense: true,
              leading: Icon(UIcons.regular.bug, size: 18, color: Theme.of(context).primaryColor),
              title: const Text('Report a Bug'),
              subtitle: const Text('Open an issue on GitHub'),
              onTap: () => launchUrl(
                Uri.parse(appConfig.bugReportUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            ListTile(
              dense: true,
              leading: Icon(UIcons.regular.coffee, size: 18, color: Theme.of(context).primaryColor),
              title: const Text('Buy me a Coffee'),
              subtitle: const Text('Support development with a donation'),
              onTap: () => _handleDonation(context, ref),
            ),
          ],
        ),
        _buildNavigationItem(
          context,
          icon: UIcons.regular.download,
          title: 'Check for Updates',
          subtitle: 'Browse releases, view changelogs, or update',
          onTap: () {
            if (onOpenUpdates != null) {
              onOpenUpdates!();
            }
          },
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 18, color: theme.primaryColor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: Icon(UIcons.regular.angle_small_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _handleDonation(BuildContext context, WidgetRef ref) async {
    final appConfig = ref.read(appConfigProvider);
    final donateUrl = appConfig.donateUrl;
    
    try {
      if (await canLaunchUrl(Uri.parse(donateUrl))) {
        await launchUrl(Uri.parse(donateUrl), mode: LaunchMode.externalApplication);
        return;
      }
      throw Exception('Could not launch donate url');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open donation link.')),
        );
      }
    }
  }
}
