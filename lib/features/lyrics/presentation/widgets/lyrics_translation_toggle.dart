import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/lyrics_translation_provider.dart';
import '../../../../core/widgets/reusable_hover_icon_button.dart';

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
    
    // SOTA V12.5: Centralized Label Logic
    String label = 'OFF';
    String tooltipMessage = 'Aktifkan Terjemahan';
    
    if (state.mode == LyricsTranslationMode.romanized) {
      label = 'ROM';
      tooltipMessage = 'Ganti ke Lirik Asli';
    } else if (state.mode == LyricsTranslationMode.translated) {
      label = 'TRN';
      tooltipMessage = 'Ganti ke Mode Romanisasi';
    } else {
      // mode == original
      label = 'OFF';
      tooltipMessage = 'Aktifkan Terjemahan';
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
