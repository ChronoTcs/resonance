import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/lyrics_translation_provider.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';

class LyricsTranslationToggle extends ConsumerWidget {
  final double iconSize;
  final double fontSize;
  final double padding;
  final Color? color;

  const LyricsTranslationToggle({
    super.key,
    this.iconSize = 24.0,
    this.fontSize = 12.0,
    this.padding = 4.0,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lyricsTranslationProvider);
    final theme = Theme.of(context);
    final isOnline = ref.watch(networkConnectivityProvider.select((s) => s.isOnline));
    final effectiveColor = color ?? theme.colorScheme.onSurface;
    
    String label = 'OFF';
    String tooltipMessage = 'Enable Translation';
    
    if (!isOnline) {
      tooltipMessage = 'Translation requires an internet connection';
    } else if (state.mode == LyricsTranslationMode.romanized) {
      label = 'ROM';
      tooltipMessage = 'Switch to Original Lyrics';
    } else if (state.mode == LyricsTranslationMode.translated) {
      label = 'TRN';
      tooltipMessage = 'Switch to Romanization Mode';
    } else {
      // mode == original
      label = 'OFF';
      tooltipMessage = 'Enable Translation';
    }

    return ReusableHoverIconButton(
      label: label,
      tooltip: tooltipMessage,
      isDisabled: !isOnline,
      isSelected: state.mode != LyricsTranslationMode.original,
      onTap: isOnline
          ? () => ref.read(lyricsTranslationProvider.notifier).cycleMode()
          : null,
      padding: padding,
      iconSize: iconSize,
      color: effectiveColor,
      labelStyle: TextStyle(
        fontSize: fontSize, 
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
