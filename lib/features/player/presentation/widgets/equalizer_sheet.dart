import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/inputs/resonance_switch.dart';
import 'package:resonance/core/widgets/overlays/floating_sheet_shell.dart';
import 'package:resonance/features/player/application/providers/equalizer_controller.dart';
import 'equalizer/equalizer_band_slider.dart';
import 'equalizer/equalizer_curve_visualizer.dart';
import 'equalizer/equalizer_preset_selector.dart';

/// Redesigned glassmorphic Equalizer modal sheet matching Resonance design system.
/// Features real-time Bézier curve visualizer, horizontal preset chip carousel,
/// tactile vertical sliders with dB readout, and mobile/Android screen adaptation.
class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const EqualizerSheet(),
    );
  }

  static const List<String> _bandLabels = [
    '62 Hz',
    '125 Hz',
    '250 Hz',
    '500 Hz',
    '1 kHz',
    '2 kHz',
    '4 kHz',
    '8 kHz',
    '16 kHz',
  ];

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  bool _isLinkHovered = false;

  @override
  Widget build(BuildContext context) {
    final eqState = ref.watch(equalizerControllerProvider);
    final eqNotifier = ref.read(equalizerControllerProvider.notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final screenSize = MediaQuery.sizeOf(context);
    final isShortScreen = screenSize.height < 720;

    final curveHeight = isShortScreen ? 76.0 : 88.0;
    final consoleHeight = isShortScreen ? 150.0 : 170.0;

    return FloatingSheetShell(
      maxWidth: 580,
      isScrollable: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      customHeader: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Title + Icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                UIcons.regular.settings_sliders,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Equalizer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          // Right: Reset + Power Switch + Close
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reset to flat button
              ReusableHoverIconButton(
                icon: UIcons.regular.rotate_left,
                tooltip: 'Reset to Flat',
                iconSize: 15.0,
                padding: 6.0,
                onTap: () => eqNotifier.setEqualizerPreset('Flat'),
              ),
              const SizedBox(width: 6),

              // Power switch with status text
              Text(
                eqState.isEnabled ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: eqState.isEnabled
                      ? colorScheme.primary
                      : onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              ResonanceSwitch(
                value: eqState.isEnabled,
                onChanged: (val) => eqNotifier.toggleEqualizer(val),
              ),
              const SizedBox(width: 6),

              // Close button
              ReusableHoverIconButton(
                icon: UIcons.regular.cross_small,
                tooltip: 'Close',
                iconSize: 13.0,
                padding: 6.0,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
      children: [
        // 1. Real-time Frequency Response Curve Visualizer
        EqualizerCurveVisualizer(
          bands: eqState.bands,
          isEnabled: eqState.isEnabled,
          height: curveHeight,
        ),
        const SizedBox(height: 14),

        // 2. Preset Chip Carousel & Categorized Modal Selector
        EqualizerPresetSelector(
          activePreset: eqState.preset,
          onPresetSelected: (preset) => eqNotifier.setEqualizerPreset(preset),
        ),
        const SizedBox(height: 18),

        // 3. Adaptive 9-Band Sliders Console
        EqualizerBandsConsole(
          labels: EqualizerSheet._bandLabels,
          bands: eqState.bands,
          isEnabled: eqState.isEnabled,
          height: consoleHeight,
          onBandChanged: (index, value) =>
              eqNotifier.setEqualizerBand(index, value),
        ),
        const SizedBox(height: 14),

        // 4. Bottom Controls: Link Nearby Sliders Checkbox
        Divider(
          thickness: 1,
          color: colorScheme.outline.withValues(alpha: 0.08),
        ),
        const SizedBox(height: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isLinkHovered = true),
          onExit: (_) => setState(() => _isLinkHovered = false),
          child: GestureDetector(
            onTap: () => eqNotifier.toggleLinkSliders(!eqState.linkSliders),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: _isLinkHovered
                    ? colorScheme.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: eqState.linkSliders,
                      activeColor: colorScheme.primary,
                      checkColor: colorScheme.onPrimary,
                      side: BorderSide(color: onSurfaceVariant.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          eqNotifier.toggleLinkSliders(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Move nearby sliders together',
                      style: TextStyle(
                        color: _isLinkHovered ? onSurface : onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: _isLinkHovered
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
