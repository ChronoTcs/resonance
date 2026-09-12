import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:resonance/core/application/providers/app_config_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/resonance_button.dart';
import 'package:resonance/features/library/application/services/music_restore_service.dart';
import 'package:resonance/features/settings/application/update_provider.dart';
import '../screens/settings_screen.dart';
import '../providers/package_info_provider.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

class AboutCard extends ConsumerStatefulWidget {
  final VoidCallback? onOpenUpdates;

  const AboutCard({super.key, this.onOpenUpdates});

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
        ref.read(notificationProvider.notifier).showNotification(
          'Secret Protocol',
          '5 more taps to open the secret protocol...',
          silentOsNotification: true,
        );
      }
      if (_tapCount >= 10 && !_showRestore) {
        _showRestore = true;
        ref.read(notificationProvider.notifier).showNotification(
          'Restore Protocol',
          'Restricted access granted.',
          silentOsNotification: true,
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
      
      ref.read(notificationProvider.notifier).showNotification(
        'Restore Protocol',
        'Metadata & Media re-synced successfully.',
        target: 'target:library',
        silentOsNotification: true,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      
      ref.read(notificationProvider.notifier).showNotification(
        'Restore Failed',
        'Protocol Failed: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
        silentOsNotification: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(packageInfoProvider);
    final updateState = ref.watch(updateProvider);
    final repoUrl = ref.watch(appConfigProvider.select((c) => c.repoUrl));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;
          final iconSize = isCompact ? 38.0 : 44.0;

          return Material(
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: isCompact ? 4 : 8,
                ),
                collapsedBackgroundColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                leading: Container(
                  height: iconSize,
                  width: iconSize,
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
                  style: TextStyle(
                    fontSize: isCompact ? 15 : 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  isCompact ? '© 2026 ChronoTech' : '© 2026 ChronoTech. All rights reserved.',
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _AboutCardVersionBadge(
                  packageInfo: packageInfo,
                  updateState: updateState,
                  isCompact: isCompact,
                ),
                children: [
                  const Divider(height: 1),
                  _AboutCardExpandedContent(
                    onTap: _handleTap,
                    showRestore: _showRestore,
                    onRestore: _handleRestore,
                    repoUrl: repoUrl,
                    packageInfo: packageInfo,
                    updateState: updateState,
                    isCompact: isCompact,
                    onCheckUpdates: () => ref.read(updateProvider.notifier).fetchReleases(),
                    onOpenUpdates: widget.onOpenUpdates ??
                        () => ref.read(settingsSubViewProvider.notifier).setSubView(SettingsSubView.updates),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutCardVersionBadge extends StatelessWidget {
  final AsyncValue<dynamic> packageInfo;
  final UpdateState updateState;
  final bool isCompact;

  const _AboutCardVersionBadge({
    required this.packageInfo,
    required this.updateState,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionStr = packageInfo.maybeWhen(
      data: (info) => isCompact ? 'v${info.version}' : 'Version ${info.version}',
      orElse: () => 'v?.?.?',
    );

    Widget badgeContent;
    Color badgeBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    Border? badgeBorder;

    if (updateState.isChecking) {
      badgeBg = theme.colorScheme.primary.withValues(alpha: 0.12);
      badgeBorder = Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3));
      badgeContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isCompact ? 'Checking...' : '$versionStr • Checking...',
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    } else if (updateState.isUpdateReadyToRestart) {
      badgeBg = Colors.amber.withValues(alpha: 0.15);
      badgeBorder = Border.all(color: Colors.amber.withValues(alpha: 0.4));
      badgeContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(UIcons.regular.refresh, size: 11, color: Colors.amber.shade400),
          const SizedBox(width: 4),
          Text(
            isCompact ? 'Restart' : '$versionStr • Restart ready',
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade400,
            ),
          ),
        ],
      );
    } else if (updateState.updateAvailable) {
      badgeBg = theme.colorScheme.primary.withValues(alpha: 0.15);
      badgeBorder = Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4));
      badgeContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isCompact ? 'Update ready' : '$versionStr • Update available',
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    } else if (updateState.releases.isNotEmpty && !updateState.updateAvailable) {
      badgeContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(UIcons.regular.check, size: 10, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            isCompact ? versionStr : '$versionStr • Latest',
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else {
      badgeContent = Text(
        versionStr,
        style: TextStyle(
          fontSize: isCompact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 8,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(6),
            border: badgeBorder,
          ),
          child: badgeContent,
        ),
        const SizedBox(width: 6),
        Icon(UIcons.regular.angle_small_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

class _AboutCardExpandedContent extends StatelessWidget {
  final VoidCallback onTap;
  final bool showRestore;
  final VoidCallback onRestore;
  final String repoUrl;
  final AsyncValue<dynamic> packageInfo;
  final UpdateState updateState;
  final bool isCompact;
  final VoidCallback onCheckUpdates;
  final VoidCallback onOpenUpdates;

  const _AboutCardExpandedContent({
    required this.onTap,
    required this.showRestore,
    required this.onRestore,
    required this.repoUrl,
    required this.packageInfo,
    required this.updateState,
    required this.isCompact,
    required this.onCheckUpdates,
    required this.onOpenUpdates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
                  onTap: onTap,
                  child: Text(
                    'Premium Hybrid Music Streaming App for Windows & Android',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (showRestore)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton.icon(
                    onPressed: onRestore,
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
          const SizedBox(height: 12),
          _AboutCardUpdateSection(
            updateState: updateState,
            packageInfo: packageInfo,
            isCompact: isCompact,
            onCheckUpdates: onCheckUpdates,
            onOpenUpdates: onOpenUpdates,
          ),
          const SizedBox(height: 12),
          _AboutCardLinkRow(
            text: 'Licence Terms',
            url: '$repoUrl/blob/main/LICENSE',
          ),
          _AboutCardLinkRow(
            text: 'Project Documentation (README)',
            url: '$repoUrl#readme',
          ),
          _AboutCardLinkRow(
            text: 'GitHub Repository',
            url: repoUrl,
          ),
        ],
      ),
    );
  }
}

class _AboutCardUpdateSection extends StatelessWidget {
  final UpdateState updateState;
  final AsyncValue<dynamic> packageInfo;
  final bool isCompact;
  final VoidCallback onCheckUpdates;
  final VoidCallback onOpenUpdates;

  const _AboutCardUpdateSection({
    required this.updateState,
    required this.packageInfo,
    required this.isCompact,
    required this.onCheckUpdates,
    required this.onOpenUpdates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVersion = packageInfo.maybeWhen(
      data: (info) => 'v${info.version}',
      orElse: () => 'v?.?.?',
    );

    final Widget leadingIcon;
    final String title;
    final String subtitle;
    Color iconColor = theme.colorScheme.onSurfaceVariant;

    if (updateState.isChecking) {
      leadingIcon = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.primaryColor,
        ),
      );
      title = 'Checking for updates...';
      subtitle = 'Querying GitHub release channels';
    } else if (updateState.isUpdateReadyToRestart) {
      iconColor = Colors.amber.shade400;
      leadingIcon = Icon(UIcons.regular.refresh, size: 18, color: iconColor);
      title = 'Update ready to install';
      subtitle = 'Restart Resonance to apply ${updateState.stagedVersion ?? 'update'}';
    } else if (updateState.updateAvailable) {
      iconColor = theme.primaryColor;
      leadingIcon = Icon(UIcons.regular.download, size: 18, color: iconColor);
      title = 'Update available: ${updateState.latestVersion}';
      subtitle = 'Tap to view changelog and install new version';
    } else if (updateState.releases.isNotEmpty && !updateState.updateAvailable) {
      iconColor = theme.primaryColor;
      leadingIcon = Icon(UIcons.regular.check, size: 18, color: iconColor);
      title = "You're on the latest version";
      subtitle = 'Resonance is up to date ($currentVersion)';
    } else if (updateState.error != null) {
      iconColor = theme.colorScheme.error;
      leadingIcon = Icon(Icons.error_outline, size: 18, color: iconColor);
      title = 'Update check failed';
      subtitle = updateState.error!;
    } else {
      leadingIcon = Icon(UIcons.regular.download, size: 18, color: iconColor);
      title = 'Software Updates';
      subtitle = 'Current installed: $currentVersion';
    }

    final isHighlight = updateState.updateAvailable || updateState.isUpdateReadyToRestart;

    final Widget actionButton;
    if (updateState.isUpdateReadyToRestart) {
      actionButton = ResonanceButton(
        onPressed: onOpenUpdates,
        label: 'Restart',
        icon: Icons.restart_alt,
        style: ResonanceButtonStyle.primary,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );
    } else if (updateState.updateAvailable) {
      actionButton = ResonanceButton(
        onPressed: onOpenUpdates,
        label: 'View Update',
        icon: UIcons.regular.download,
        style: ResonanceButtonStyle.primary,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );
    } else {
      actionButton = ResonanceButton(
        onPressed: updateState.isChecking ? null : onCheckUpdates,
        label: updateState.error != null ? 'Retry' : 'Check Now',
        icon: UIcons.regular.refresh,
        style: ResonanceButtonStyle.secondary,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      );
    }

    final statusTexts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final Widget releaseNotesLink = ResonanceButton(
      onPressed: onOpenUpdates,
      label: 'Releases',
      icon: UIcons.regular.info,
      style: ResonanceButtonStyle.secondary,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? theme.primaryColor.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leadingIcon,
                    const SizedBox(width: 10),
                    Expanded(child: statusTexts),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!updateState.updateAvailable && !updateState.isUpdateReadyToRestart) ...[
                      releaseNotesLink,
                      const SizedBox(width: 6),
                    ],
                    actionButton,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                leadingIcon,
                const SizedBox(width: 12),
                Expanded(child: statusTexts),
                const SizedBox(width: 12),
                if (!updateState.updateAvailable && !updateState.isUpdateReadyToRestart) ...[
                  releaseNotesLink,
                  const SizedBox(width: 6),
                ],
                actionButton,
              ],
            ),
    );
  }
}

class _AboutCardLinkRow extends StatelessWidget {
  final String text;
  final String url;

  const _AboutCardLinkRow({required this.text, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ),
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
