class SyllableWord {
  final String text;
  final Duration offset; // Relative to line start
  final Duration duration;

  SyllableWord({
    required this.text,
    required this.offset,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'offsetMs': offset.inMilliseconds,
      'durationMs': duration.inMilliseconds,
    };
  }

  factory SyllableWord.fromJson(Map<String, dynamic> json) {
    return SyllableWord(
      text: json['text'] as String,
      offset: Duration(milliseconds: json['offsetMs'] as int),
      duration: Duration(milliseconds: json['durationMs'] as int),
    );
  }
}

class SyllableLyricLine {
  final Duration timestamp;
  final String fullText;
  final List<SyllableWord> words;

  SyllableLyricLine({
    required this.timestamp,
    required this.fullText,
    required this.words,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestampMs': timestamp.inMilliseconds,
      'fullText': fullText,
      'words': words.map((w) => w.toJson()).toList(),
    };
  }

  factory SyllableLyricLine.fromJson(Map<String, dynamic> json) {
    return SyllableLyricLine(
      timestamp: Duration(milliseconds: json['timestampMs'] as int),
      fullText: json['fullText'] as String,
      words: (json['words'] as List<dynamic>)
          .map((w) => SyllableWord.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}
