class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});

  @override
  String toString() => 'LyricLine(time: \$timestamp, text: \$text)';
}
