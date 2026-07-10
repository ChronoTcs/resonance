import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
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

  static const Map<String, List<Color>> _paletteGradients = {
    'palette1': [Color(0xFFDBCDC2), Color(0xFFA89689)],
    'palette2': [Color(0xFFFCFAF5), Color(0xFFDDD4C5)],
    'palette3': [Color(0xFFE4ECE8), Color(0xFFA3B5AE)],
    'palette4': [Color(0xFFE2EBEE), Color(0xFFA5B6BD)],
    'palette5': [Color(0xFFCBD8DF), Color(0xFF8A9EA9)],
    'palette6': [Color(0xFFB7C9D1), Color(0xFF738995)],
    'palette7': [Color(0xFFE9AD71), Color(0xFFFFCEAA)],
    'palette8': [Color(0xFFAE8C50), Color(0xFFBB6B4C)],
  };

  Widget _buildThemeSetting(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    
    return SettingsItemTile(
      icon: UIcons.regular.palette,
      title: 'App Theme',
      subtitle: 'Select visual mode',
      trailing: HoverDropdownWrapper(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AppThemeMode>(
            value: themeMode,
            dropdownColor: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            focusColor: Colors.transparent,
            icon: Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Icon(UIcons.regular.angle_small_down, size: 16),
            ),
            items: const [
              DropdownMenuItem(
                value: AppThemeMode.system, 
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('System Default', style: TextStyle(fontSize: 14)),
                ),
              ),
              DropdownMenuItem(
                value: AppThemeMode.light, 
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Modern Glass (Light)', style: TextStyle(fontSize: 14)),
                ),
              ),
              DropdownMenuItem(
                value: AppThemeMode.dark, 
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Deep Opulence (Dark)', style: TextStyle(fontSize: 14)),
                ),
              ),
              DropdownMenuItem(
                value: AppThemeMode.onyx, 
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Onyx (Pure Dark)', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) ref.read(themeProvider.notifier).setTheme(mode);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAccentSetting(BuildContext context, WidgetRef ref) {
    final accentMode = ref.watch(accentColorProvider);
    final theme = Theme.of(context);

    DropdownMenuItem<String?> buildItem(String? value, String text, [List<Color>? colors]) {
      return DropdownMenuItem<String?>(
        value: value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: const TextStyle(fontSize: 14)),
              if (colors != null) ...[
                const SizedBox(width: 12),
                Container(
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
              ],
            ],
          ),
        ),
      );
    }

    return SettingsItemTile(
      icon: UIcons.regular.paint_brush,
      title: 'Accent colour',
      subtitle: 'Select primary accent',
      trailing: HoverDropdownWrapper(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: accentMode,
            dropdownColor: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            focusColor: Colors.transparent,
            icon: Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Icon(UIcons.regular.angle_small_down, size: 16),
            ),
            items: [
              buildItem(null, 'Default Accent'),
              buildItem('windows', 'Windows Accent'),
              buildItem('palette1', 'Palette 1', _paletteGradients['palette1']),
              buildItem('palette2', 'Palette 2', _paletteGradients['palette2']),
              buildItem('palette3', 'Palette 3', _paletteGradients['palette3']),
              buildItem('palette4', 'Palette 4', _paletteGradients['palette4']),
              buildItem('palette5', 'Palette 5', _paletteGradients['palette5']),
              buildItem('palette6', 'Palette 6', _paletteGradients['palette6']),
              buildItem('palette7', 'Palette 7', _paletteGradients['palette7']),
              buildItem('palette8', 'Palette 8', _paletteGradients['palette8']),
            ],
            onChanged: (mode) => ref.read(accentColorProvider.notifier).setAccentColor(mode),
          ),
        ),
      ),
    );
  }
}

class HoverDropdownWrapper extends StatefulWidget {
  final Widget child;
  const HoverDropdownWrapper({super.key, required this.child});

  @override
  State<HoverDropdownWrapper> createState() => _HoverDropdownWrapperState();
}

class _HoverDropdownWrapperState extends State<HoverDropdownWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        decoration: BoxDecoration(
          color: _isHovered 
              ? activeColor.withValues(alpha: 0.12) 
              : theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered 
                ? activeColor.withValues(alpha: 0.4) 
                : theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
