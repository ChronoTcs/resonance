import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/resonance_selector.dart';
import 'package:resonance/core/widgets/resonance_slider.dart';
import '../../../../core/theme/theme_provider.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final accentMode = ref.watch(accentColorProvider);
    final activeOpacity = ref.watch(lyricsActiveOpacityProvider);
    final inactiveOpacity = ref.watch(lyricsInactiveOpacityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App & Appearance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Theme selector
        ResonanceSelector<AppThemeMode>(
          icon: UIcons.regular.palette,
          title: 'App Theme',
          subtitle: 'Select visual mode',
          value: themeMode,
          onChanged: (v) => ref.read(themeProvider.notifier).setTheme(v),
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
            const ResonanceSelectorItem(value: null,      label: 'Default Accent'),
            const ResonanceSelectorItem(value: 'windows', label: 'Windows Accent'),
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
        const Text(
          'Lyrics Opacity',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 12),

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

        const SizedBox(height: 32),
      ],
    );
  }
}
