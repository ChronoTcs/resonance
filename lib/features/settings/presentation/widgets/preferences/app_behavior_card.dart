import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/inputs/resonance_switch.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';

/// Card containing application startup, tray behavior, and queue prefetch toggles.
class AppBehaviorCard extends ConsumerWidget {
  const AppBehaviorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appBehavior = ref.watch(appBehaviorProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Behavior',
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
              if (Platform.isWindows) ...[
                // Launch at Startup
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(UIcons.regular.laptop, size: 18, color: theme.primaryColor),
                  title: const Text('Launch at Startup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Automatically open Resonance when Windows boots up',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: ResonanceSwitch(
                    value: appBehavior.autoStartOnBoot,
                    onChanged: (val) => ref.read(appBehaviorProvider.notifier).setAutoStartOnBoot(val),
                  ),
                ),
                const Divider(height: 1),

                // Close to Tray
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(
                    UIcons.regular.compress_alt,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                  title: const Text(
                    'Minimize to System Tray on Close',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Closing the window keeps Resonance running in the background tray',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: ResonanceSwitch(
                    value: appBehavior.closeToTray,
                    onChanged: (val) => ref.read(appBehaviorProvider.notifier).setCloseToTray(val),
                  ),
                ),
                const Divider(height: 1),
              ],

              // Deep Queue Prefetch
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(UIcons.regular.bolt, size: 18, color: theme.primaryColor),
                title: const Text(
                  'Deep Queue Prefetch',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Pre-cache upcoming tracks in queue for seamless, gapless playback',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: ResonanceSwitch(
                  value: appBehavior.deepQueuePrefetch,
                  onChanged: (val) => ref.read(appBehaviorProvider.notifier).setDeepQueuePrefetch(val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

