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
      return _queue.firstWhere((item) => (item.id ?? item.path) == nextId);
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _queue.length) {
        return _loopMode == LoopMode.all ? _queue.first : null;
      }
      return _queue[nextIndex];
    }
  }

  int getNextIndex({bool fromCompletion = false}) {
    // debugPrint('QueueService.getNextIndex: fromCompletion=$fromCompletion, _currentIndex=$_currentIndex, _queue.length=${_queue.length}, _loopMode=$_loopMode');
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
      return _queue.indexWhere((item) => (item.id ?? item.path) == nextId);
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
        return _queue.indexWhere((item) => (item.id ?? item.path) == prevId);
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

  MediaItem? getNextTrack(LoopMode loopMode, bool isShuffleEnabled, {bool fromCompletion = false}) {
    _loopMode = loopMode;
    _isShuffleEnabled = isShuffleEnabled;
    int nextIndex = getNextIndex(fromCompletion: fromCompletion);
    debugPrint('QueueService.getNextTrack: nextIndex=$nextIndex');
    if (nextIndex != -1) {
      _currentIndex = nextIndex;
      return _queue[_currentIndex];
    }
    return null;
  }

  /// Appends a single track without resetting the queue cursor.
  void appendTrack(MediaItem item) {
    _queue = [..._queue, item];
  }

  /// Appends multiple tracks without resetting the queue cursor.
  void appendTracks(List<MediaItem> items) {
    _queue = [..._queue, ...items];
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
    return nextTrack;
  }

  /// Returns the track at [index] without mutating any state.
  /// Returns null if index is out of bounds.
  // ponytail: simple direct lookup, no shuffle awareness needed for N+2 peek
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

    if (lastPlayedId != null && _shuffleQueue.length > 1 && _shuffleQueue.first == lastPlayedId) {
      final first = _shuffleQueue.removeAt(0);
      _shuffleQueue.insert(Random().nextInt(_shuffleQueue.length) + 1, first);
    }
  }

  MediaItem? _peekNextShuffleTrack() {
     if (_queue.isEmpty) return null;
     
     List<String> peekQueue = _queue.map((item) => item.id ?? item.path).toList();
     peekQueue.shuffle();
     
     final lastPlayedId = currentTrack?.id ?? currentTrack?.path;
     if (lastPlayedId != null && peekQueue.length > 1 && peekQueue.first == lastPlayedId) {
       return _queue.firstWhere((item) => (item.id ?? item.path) == peekQueue[1]);
     }
     return _queue.firstWhere((item) => (item.id ?? item.path) == peekQueue.first);
  }
}
