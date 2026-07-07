import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_app/core/utils/uicons.dart';
import '../../../../core/theme/theme_provider.dart';
import 'settings_widgets.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App & Appearance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildThemeSetting(context, ref),
        const SizedBox(height: 12),
        _buildAccentSetting(context, ref),
      ],
    );
  }

  Widget _buildThemeSetting(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return SettingsItemTile(
      icon: UIcons.regular.palette,
      title: 'App Theme',
      subtitle: 'Select visual mode',
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        dropdownColor: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        focusColor: Colors.transparent,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light (Cream)')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark (Monochrome)')),
        ],
        onChanged: (mode) {
          if (mode != null) ref.read(themeProvider.notifier).setTheme(mode);
        },
      ),
    );
  }

  Widget _buildAccentSetting(BuildContext context, WidgetRef ref) {
    final accentMode = ref.watch(accentColorProvider);
    return SettingsItemTile(
      icon: UIcons.regular.paint_brush,
      title: 'Accent colour',
      subtitle: 'Select primary accent',
      trailing: DropdownButton<String?>(
        value: accentMode,
        dropdownColor: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        focusColor: Colors.transparent,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: null, child: Text('Default Accent')),
          DropdownMenuItem(value: 'windows', child: Text('Windows Accent')),
          DropdownMenuItem(value: 'palette1', child: Text('Palette 1 (Muted Sand)')),
          DropdownMenuItem(value: 'palette2', child: Text('Palette 2 (Cream Alabaster)')),
          DropdownMenuItem(value: 'palette3', child: Text('Palette 3 (Sage & Slate Mint)')),
          DropdownMenuItem(value: 'palette4', child: Text('Palette 4 (Glacier Steel)')),
          DropdownMenuItem(value: 'palette5', child: Text('Palette 5 (Nordic Blue)')),
          DropdownMenuItem(value: 'palette6', child: Text('Palette 6 (Deep Dusk Blue)')),
          DropdownMenuItem(value: 'palette7', child: Text('Palette 7 (Auroral Glow)')),
          DropdownMenuItem(value: 'palette8', child: Text('Palette 8 (Copper-Amber)')),
        ],
        onChanged: (mode) => ref.read(accentColorProvider.notifier).setAccentColor(mode),
      ),
    );
  }
}
