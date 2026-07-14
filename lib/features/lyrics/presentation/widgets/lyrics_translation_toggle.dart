import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/lyrics_translation_provider.dart';
import 'package:resonance/core/widgets/widgets.dart';

class LyricsTranslationToggle extends ConsumerWidget {
  final double iconSize;
  final double fontSize;
  final double padding;

  const LyricsTranslationToggle({
    super.key,
    this.iconSize = 24.0,
    this.fontSize = 12.0,
    this.padding = 4.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lyricsTranslationProvider);
    
    String label = 'OFF';
    String tooltipMessage = 'Enable Translation';
    
    if (state.mode == LyricsTranslationMode.romanized) {
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
      isSelected: state.mode != LyricsTranslationMode.original,
      onTap: () => ref.read(lyricsTranslationProvider.notifier).cycleMode(),
      padding: padding,
      iconSize: iconSize,
      labelStyle: TextStyle(
        fontSize: fontSize, 
        fontWeight: FontWeight.bold
      ),
    );
  }
}
