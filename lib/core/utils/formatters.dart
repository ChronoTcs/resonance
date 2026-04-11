class AppFormatters {
  /// Formats a [Duration] into a human-readable string (HH:MM:SS or MM:SS).
  static String formatDuration(Duration d) {
    if (d.isNegative) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
