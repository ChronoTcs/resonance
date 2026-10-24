import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/inputs/resonance_switch.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';
import 'package:resonance/features/settings/presentation/screens/settings_screen.dart';

/// Card containing background update download preferences and release history navigation.
class PreferencesUpdatesCard extends ConsumerWidget {
  const PreferencesUpdatesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final autoUpdate = ref.watch(appBehaviorProvider.select((s) => s.autoUpdate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Updates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(UIcons.regular.cloud_download, size: 18, color: theme.primaryColor),
                title: const Text(
                  'Automatic Updates',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  Platform.isAndroid
                      ? 'Automatically check and download APK updates in background. Install prompt requested when ready.'
                      : 'Automatically check and download updates in background when available',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: ResonanceSwitch(
                  value: autoUpdate,
                  onChanged: (val) {
                    ref.read(appBehaviorProvider.notifier).setAutoUpdate(val);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Icon(UIcons.regular.refresh, size: 16, color: theme.colorScheme.onSurfaceVariant),
                title: const Text('Check for Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: const Text('View release history, staging status and changelogs', style: TextStyle(fontSize: 11)),
                trailing: Icon(UIcons.regular.angle_small_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
                onTap: () {
                  ref.read(settingsSubViewProvider.notifier).setSubView(SettingsSubView.updates);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

