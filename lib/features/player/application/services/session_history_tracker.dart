import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionHistoryTrackerProvider = Provider<SessionHistoryTracker>((ref) {
  return SessionHistoryTracker();
});

/// In-memory ring buffer tracking tracks played within the current playback session.
/// Guarantees 0 duplicate plays when generating auto-continue radio queues.
class SessionHistoryTracker {
  final List<String> _order = [];
  final Set<String> _set = {};
  static const int _maxSize = 100;

  /// Records a track ID into the session ring buffer.
  void recordPlayed(String? id) {
    if (id == null || id.isEmpty) return;
    final cleanId = id.trim();
    if (_set.contains(cleanId)) {
      _order.remove(cleanId);
    }
    _order.add(cleanId);
    _set.add(cleanId);

    if (_order.length > _maxSize) {
      final removed = _order.removeAt(0);
      _set.remove(removed);
    }
  }

  /// Checks if a track ID has already been played in this session.
  bool wasPlayedRecently(String? id) {
    if (id == null || id.isEmpty) return false;
    return _set.contains(id.trim());
  }

  /// Read-only snapshot of all track IDs played during this session.
  Set<String> get recentIds => Set.unmodifiable(_set);

  /// Clears the session buffer.
  void clear() {
    _order.clear();
    _set.clear();
  }
}
