import 'dart:io';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';
import 'package:system_theme/system_theme.dart';

import '../../../../core/theme/theme_provider.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  static const Map<String, List<Color>> _paletteGradients = {
    'palette1': [Color(0xFFDBCDC2), Color(0xFFA89689)],
    'palette2': [Color(0xFFFCFAF5), Color(0xFFDDD4C5)],
    'palette3': [Color(0xFFE4ECE8), Color(0xFFA3B5AE)],
    'palette4': [Color(0xFF60A5FA), Color(0xFF2563EB)],
    'palette5': [Color(0xFF34D399), Color(0xFF059669)],
    'palette6': [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    'palette7': [Color(0xFFE9AD71), Color(0xFFFFCEAA)],
    'palette8': [Color(0xFFAE8C50), Color(0xFFBB6B4C)],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final accentMode = ref.watch(accentColorProvider);
    final activeOpacity = ref.watch(lyricsActiveOpacityProvider);
    final inactiveOpacity = ref.watch(lyricsInactiveOpacityProvider);
    final appBehavior = ref.watch(appBehaviorProvider);
    final systemAccentLabel = Platform.isAndroid ? 'System Accent' : 'Windows Accent';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App & Appearance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 16),

        // Theme selector
        ResonanceSelector<AppThemeMode>(
          icon: UIcons.regular.palette,
          title: 'App Theme',
          subtitle: 'Choose your visual preference',
          value: themeMode,
          onChanged: (mode) => ref.read(themeProvider.notifier).setTheme(mode),
          items: const [
            ResonanceSelectorItem(value: AppThemeMode.system, label: 'System Default'),
            ResonanceSelectorItem(value: AppThemeMode.light,  label: 'Gilded Ivory (Light)'),
            ResonanceSelectorItem(value: AppThemeMode.dark,   label: 'Deep Opulence (Dark)'),
            ResonanceSelectorItem(value: AppThemeMode.onyx,   label: 'Onyx (Pure Dark)'),
          ],
        ),

        const SizedBox(height: 12),

        // Accent selector
        ResonanceSelector<String?>(
          icon: UIcons.regular.paint_brush,
          title: 'Accent Colour',
          subtitle: 'Select primary accent',
          value: accentMode,
          onChanged: (v) => ref.read(accentColorProvider.notifier).setAccentColor(v),
          items: [
            ResonanceSelectorItem(
              value: null,
              label: 'Default Accent',
              leading: Container(
                width: 32,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE9AD71), Color(0xFFAE8C50)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            ResonanceSelectorItem(
              value: 'windows',
              label: systemAccentLabel,
              leading: Container(
                width: 32,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: SystemTheme.accentColor.accent,
                ),
              ),
            ),
            ..._paletteGradients.entries.indexed.map((e) {
              final idx = e.$1 + 1;
              final key = e.$2.key;
              final colors = e.$2.value;
              return ResonanceSelectorItem<String?>(
                value: key,
                label: 'Palette $idx',
                leading: Container(
                  width: 32,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Lyrics Opacity',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 12),

        // Lyrics Opacity grouped card
        Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Highlighted Line Opacity
                ResonanceSlider(
                  title: 'Highlighted Line Opacity (${(activeOpacity * 100).toInt()}%)',
                  value: activeOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (val) => ref.read(lyricsActiveOpacityProvider.notifier).setOpacity(val),
                ),
                const SizedBox(height: 12),
                // Inactive Lines Opacity
                ResonanceSlider(
                  title: 'Non-highlighted Lines Opacity (${(inactiveOpacity * 100).toInt()}%)',
                  value: inactiveOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (val) => ref.read(lyricsInactiveOpacityProvider.notifier).setOpacity(val),
                ),
              ],
            ),
          ),
        ),

        if (Platform.isWindows) ...[
          const SizedBox(height: 24),
          Text(
            'App Behavior',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),

          // Grouped Card Container for App Behavior settings (Desktop only)
          Material(
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                // Launch at Startup switch
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

                // Close / Background behavior switch
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
              ],
            ),
          ),
        ],
      ],
    );
  }
}

