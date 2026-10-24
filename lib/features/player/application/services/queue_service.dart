import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../library/data/models/media_item.dart';
import '../../data/models/player_enums.dart';

final queueServiceProvider = Provider<QueueService>((ref) {
  return QueueService();
});

class QueueService {
  List<MediaItem> _queue = [];
  int _currentIndex = -1;
  LoopMode _loopMode = LoopMode.off;
  bool _isShuffleEnabled = false;

  List<String> _shuffleQueue = [];
  int _shuffleQueueIndex = -1;

  List<MediaItem> get queue => _queue;
  int get currentIndex => _currentIndex;
  LoopMode get loopMode => _loopMode;
  bool get isShuffleEnabled => _isShuffleEnabled;

  void setQueue(List<MediaItem> newQueue, {int initialIndex = 0}) {
    _queue = List.from(newQueue);
    _currentIndex = initialIndex;
    if (_isShuffleEnabled) {
      _resetShuffleQueue();
    }
  }

  void setLoopMode(LoopMode mode) => _loopMode = mode;

  void setShuffle(bool enabled) {
    _isShuffleEnabled = enabled;
    if (enabled) {
      _resetShuffleQueue();
    } else {
      _shuffleQueue = [];
      _shuffleQueueIndex = -1;
    }
  }

  MediaItem? get currentTrack {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

  MediaItem? get nextTrack {
    if (_queue.isEmpty) return null;

    if (_loopMode == LoopMode.one) {
      return currentTrack;
    }

    if (_isShuffleEnabled) {
      if (_shuffleQueue.isEmpty) return null;
      if (_shuffleQueueIndex >= _shuffleQueue.length - 1) {
        if (_loopMode == LoopMode.all) {
          // Predictive peek for regeneration
          return _peekNextShuffleTrack();
        }
        return null; // No more tracks in shuffle with LoopMode.off
      }
      final nextId = _shuffleQueue[_shuffleQueueIndex + 1];
      return _queue.firstWhere(
        (item) => (item.id ?? item.path) == nextId,
        orElse: () => _queue.first,
      );
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _queue.length) {
        return _loopMode == LoopMode.all ? _queue.first : null;
      }
      return _queue[nextIndex];
    }
  }

  int getNextIndex({bool fromCompletion = false}) {
    if (_queue.isEmpty) return -1;

    // Repeat One logic: repeat the current track for both auto-advance and manual skip
    if (_loopMode == LoopMode.one) {
      return _currentIndex;
    }

    if (_isShuffleEnabled) {
      if (_shuffleQueueIndex >= _shuffleQueue.length - 1) {
        if (_loopMode == LoopMode.all) {
          _regenerateShuffleQueue();
          _shuffleQueueIndex = 0;
        } else {
          // If LoopMode.off or LoopMode.one (getNextIndex is only called for auto-advance)
          return -1;
        }
      } else {
        _shuffleQueueIndex++;
      }
      final nextId = _shuffleQueue[_shuffleQueueIndex];
      final targetIdx = _queue.indexWhere((item) => (item.id ?? item.path) == nextId);
      return targetIdx != -1 ? targetIdx : 0;
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _queue.length) {
        if (_loopMode == LoopMode.all) {
          return 0;
        } else {
          return -1;
        }
      }
      return nextIndex;
    }
  }

  int getPreviousIndex() {
    if (_queue.isEmpty) return -1;

    if (_isShuffleEnabled) {
      if (_shuffleQueueIndex > 0) {
        _shuffleQueueIndex--;
        final prevId = _shuffleQueue[_shuffleQueueIndex];
        final targetIdx = _queue.indexWhere((item) => (item.id ?? item.path) == prevId);
        return targetIdx != -1 ? targetIdx : _currentIndex;
      }
      return _currentIndex;
    } else {
      int prevIndex = _currentIndex - 1;
      if (prevIndex < 0) {
        return _loopMode == LoopMode.all ? _queue.length - 1 : 0;
      }
      return prevIndex;
    }
  }

  void updateIndex(int index) {
    _currentIndex = index;
  }

  void setCurrentIndex(int index) => updateIndex(index);

  void shuffleQueue() {
    _isShuffleEnabled = true;
    _resetShuffleQueue();
  }

  MediaItem? getNextTrack(
    LoopMode loopMode,
    bool isShuffleEnabled, {
    bool fromCompletion = false,
  }) {
    _loopMode = loopMode;
    _isShuffleEnabled = isShuffleEnabled;
    int nextIndex = getNextIndex(fromCompletion: fromCompletion);
    debugPrint('[QueueService] getNextTrack: nextIndex=$nextIndex');
    if (nextIndex != -1) {
      _currentIndex = nextIndex;
      return _queue[_currentIndex];
    }
    return null;
  }

  /// Appends a single track without resetting the queue cursor.
  void appendTrack(MediaItem item) {
    _queue = [..._queue, item];
    if (_isShuffleEnabled) {
      _shuffleQueue.add(item.id ?? item.path);
    }
  }

  /// Inserts a track to be played immediately next (after _currentIndex).
  void insertTrackNext(MediaItem item) {
    if (_queue.isEmpty || _currentIndex < 0) {
      _queue = [item];
      _currentIndex = 0;
      return;
    }
    final targetIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue = List.from(_queue)..insert(targetIndex, item);
    if (_isShuffleEnabled) {
      final targetShuffleIndex = (_shuffleQueueIndex + 1).clamp(0, _shuffleQueue.length);
      _shuffleQueue.insert(targetShuffleIndex, item.id ?? item.path);
    }
  }

  /// Appends multiple tracks without resetting the queue cursor.
  void appendTracks(List<MediaItem> items) {
    _queue = [..._queue, ...items];
    if (_isShuffleEnabled) {
      final newIds = items.map((e) => e.id ?? e.path).toList()..shuffle();
      _shuffleQueue.addAll(newIds);
    }
  }

  /// Reorders track at [oldIndex] to [newIndex].
  /// Designed for Flutter's modern onReorderItem callback (pre-adjusted index).
  /// Preserves the currently playing track pointer across reorders.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0) newIndex = 0;

    final item = _queue.removeAt(oldIndex);
    if (newIndex > _queue.length) newIndex = _queue.length;
    _queue.insert(newIndex, item);

    // Maintain currently playing track index accurately
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    if (_isShuffleEnabled) {
      _resetShuffleQueue();
    }
  }

  /// Removes track at [index], maintaining valid cursor.
  void removeTrackAt(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (_currentIndex > index) {
      _currentIndex -= 1;
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    if (_isShuffleEnabled) {
      _resetShuffleQueue();
    }
  }

  /// Removes all occurrences of a track matching [trackId], maintaining valid cursor.
  void removeTrackById(String trackId) {
    if (_queue.isEmpty) return;
    int index;
    while ((index = _queue.indexWhere((item) => (item.id ?? item.path) == trackId)) != -1) {
      removeTrackAt(index);
    }
  }

  /// Clears all tracks ahead in queue (after _currentIndex).
  void clearUpcoming() {
    if (_currentIndex < 0 || _queue.isEmpty) {
      _queue.clear();
      _currentIndex = -1;
    } else {
      _queue = _queue.sublist(0, _currentIndex + 1);
    }
    if (_isShuffleEnabled) {
      _resetShuffleQueue();
    }
  }

  MediaItem? getPreviousTrack() {
    int prevIndex = getPreviousIndex();
    if (prevIndex != -1) {
      _currentIndex = prevIndex;
      return _queue[_currentIndex];
    }
    return null;
  }

  MediaItem? peekNextTrack(LoopMode loopMode, bool isShuffleEnabled) {
    _loopMode = loopMode;
    _isShuffleEnabled = isShuffleEnabled;
    if (_loopMode == LoopMode.one) {
      return currentTrack;
    }
    return nextTrack;
  }

  /// Returns the track that is [offset] positions ahead in the *effective* play order.
  /// Respects shuffle mode: if shuffle is enabled, reads from [_shuffleQueue].
  /// Returns null if out of bounds.
  MediaItem? peekAhead(int offset, {bool shuffleEnabled = false}) {
    if (_loopMode == LoopMode.one) {
      return currentTrack;
    }
    if (shuffleEnabled && _shuffleQueue.isNotEmpty) {
      final targetShuffleIndex = _shuffleQueueIndex + offset;
      if (targetShuffleIndex < 0 || targetShuffleIndex >= _shuffleQueue.length) return null;
      final targetId = _shuffleQueue[targetShuffleIndex];
      try {
        return _queue.firstWhere((t) => (t.id ?? t.path) == targetId);
      } catch (_) {
        return null;
      }
    }
    final targetIndex = (_currentIndex < 0 ? 0 : _currentIndex) + offset;
    if (targetIndex < 0 || targetIndex >= _queue.length) return null;
    return _queue[targetIndex];
  }

  /// Returns ordered upcoming tracks starting from [offset] positions ahead in the effective play order.
  /// Respects shuffle mode: reads from [_shuffleQueue] when shuffle is enabled.
  List<MediaItem> getUpcomingTracks({int offset = 1, int? limit, bool shuffleEnabled = false}) {
    if (_loopMode == LoopMode.one) {
      final current = currentTrack;
      return current != null ? [current] : [];
    }
    final List<MediaItem> upcoming = [];
    if (shuffleEnabled && _shuffleQueue.isNotEmpty) {
      final startIndex = _shuffleQueueIndex + offset;
      if (startIndex >= _shuffleQueue.length) return upcoming;
      final end = limit != null
          ? (startIndex + limit).clamp(0, _shuffleQueue.length)
          : _shuffleQueue.length;
      for (int i = startIndex; i < end; i++) {
        final targetId = _shuffleQueue[i];
        final item = _queue.cast<MediaItem?>().firstWhere(
          (t) => (t?.id ?? t?.path) == targetId,
          orElse: () => null,
        );
        if (item != null) upcoming.add(item);
      }
      return upcoming;
    }
    final startIndex = (_currentIndex < 0 ? 0 : _currentIndex) + offset;
    if (startIndex >= _queue.length) return upcoming;
    final end = limit != null
        ? (startIndex + limit).clamp(0, _queue.length)
        : _queue.length;
    return _queue.sublist(startIndex, end);
  }

  /// Returns the track at [index] without mutating any state.
  /// Returns null if index is out of bounds.
  MediaItem? peekTrackAt(int index) {
    if (index < 0 || index >= _queue.length) return null;
    return _queue[index];
  }

  void _resetShuffleQueue() {
    if (_queue.isEmpty) return;

    final currentId = currentTrack?.id ?? currentTrack?.path;
    _shuffleQueue = _queue.map((item) => item.id ?? item.path).toList();
    _shuffleQueue.shuffle();

    if (currentId != null) {
      _shuffleQueue.remove(currentId);
      _shuffleQueue.insert(0, currentId);
      _shuffleQueueIndex = 0;
    } else {
      _shuffleQueueIndex = 0;
    }
  }

  void _regenerateShuffleQueue() {
    if (_queue.isEmpty) return;

    final lastPlayedId = currentTrack?.id ?? currentTrack?.path;
    _shuffleQueue = _queue.map((item) => item.id ?? item.path).toList();
    _shuffleQueue.shuffle();

    if (lastPlayedId != null &&
        _shuffleQueue.length > 1 &&
        _shuffleQueue.first == lastPlayedId) {
      final first = _shuffleQueue.removeAt(0);
      _shuffleQueue.insert(Random().nextInt(_shuffleQueue.length) + 1, first);
    }
  }

  MediaItem? _peekNextShuffleTrack() {
    if (_queue.isEmpty) return null;

    List<String> peekQueue = _queue
        .map((item) => item.id ?? item.path)
        .toList();
    peekQueue.shuffle();

    final lastPlayedId = currentTrack?.id ?? currentTrack?.path;
    if (lastPlayedId != null &&
        peekQueue.length > 1 &&
        peekQueue.first == lastPlayedId) {
      return _queue.firstWhere(
        (item) => (item.id ?? item.path) == peekQueue[1],
        orElse: () => _queue.first,
      );
    }
    return _queue.firstWhere(
      (item) => (item.id ?? item.path) == peekQueue.first,
      orElse: () => _queue.first,
    );
  }
}
