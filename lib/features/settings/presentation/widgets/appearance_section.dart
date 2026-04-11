import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          const DropdownMenuItem(value: 'windows', child: Text('Windows Accent')),
          const DropdownMenuItem(value: 'cream', child: Text('Soft Cream')),
          DropdownMenuItem(value: '0x${Colors.red.toARGB32().toRadixString(16)}', child: const Text('Red')),
          DropdownMenuItem(value: '0x${Colors.blue.toARGB32().toRadixString(16)}', child: const Text('Blue')),
          DropdownMenuItem(value: '0x${Colors.green.toARGB32().toRadixString(16)}', child: const Text('Green')),
          DropdownMenuItem(value: '0x${Colors.orange.toARGB32().toRadixString(16)}', child: const Text('Orange')),
          DropdownMenuItem(value: '0x${Colors.purple.toARGB32().toRadixString(16)}', child: const Text('Purple')),
        ],
        onChanged: (mode) => ref.read(accentColorProvider.notifier).setAccentColor(mode),
      ),
    );
  }
}
