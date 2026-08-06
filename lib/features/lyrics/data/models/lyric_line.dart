import 'syllable_lyric_line.dart';

class LyricLine {
  final Duration timestamp;
  final String text;
  final List<SyllableWord>? syllables;

  LyricLine({
    required this.timestamp,
    required this.text,
    this.syllables,
  });

  @override
  String toString() => 'LyricLine(time: $timestamp, text: $text, syllables: ${syllables?.length})';
}
