import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MiniPlayerViewState {
  normal,
  idle,
  hover,
  lyrics,
  idleLyrics
}

class MiniPlayerPopState {
  final bool isPopped;
  final MiniPlayerViewState viewState;
  final Size? originalSize;
  final Offset? originalPosition;

  MiniPlayerPopState({
    this.isPopped = false,
    this.viewState = MiniPlayerViewState.normal,
    this.originalSize,
    this.originalPosition,
  });

  MiniPlayerPopState copyWith({
    bool? isPopped,
    MiniPlayerViewState? viewState,
    Size? originalSize,
    Offset? originalPosition,
  }) {
    return MiniPlayerPopState(
      isPopped: isPopped ?? this.isPopped,
      viewState: viewState ?? this.viewState,
      originalSize: originalSize ?? this.originalSize,
      originalPosition: originalPosition ?? this.originalPosition,
    );
  }
}

class MiniPlayerPopNotifier extends Notifier<MiniPlayerPopState> {
  Timer? _idleTimer;
  
  @override
  MiniPlayerPopState build() {
    ref.onDispose(() {
      _idleTimer?.cancel();
    });
    return MiniPlayerPopState();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 10), () {
      if (!state.isPopped) return;

      if (state.viewState == MiniPlayerViewState.lyrics) {
        state = state.copyWith(viewState: MiniPlayerViewState.idleLyrics);
      } else if (state.viewState != MiniPlayerViewState.idle && state.viewState != MiniPlayerViewState.idleLyrics) {
        state = state.copyWith(viewState: MiniPlayerViewState.idle);
      }
    });
  }

  void resetIdleTimer() {
    if (!state.isPopped) return;
    
    if (state.viewState == MiniPlayerViewState.idle) {
      state = state.copyWith(viewState: MiniPlayerViewState.normal);
    } else if (state.viewState == MiniPlayerViewState.idleLyrics) {
      state = state.copyWith(viewState: MiniPlayerViewState.lyrics);
    }
    
    _startIdleTimer();
  }

  void setViewState(MiniPlayerViewState view) {
    if (!state.isPopped) return;
    
    state = state.copyWith(viewState: view);
    
    _startIdleTimer();
  }

  Future<void> togglePop() async {
    if (!Platform.isWindows) return;

    if (state.isPopped) {
      await _closeMiniPlayer();
    } else {
      await _openMiniPlayer();
    }
  }

  Future<void> _openMiniPlayer() async {
    final size = await windowManager.getSize();
    final pos = await windowManager.getPosition();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('window_width', size.width);
      await prefs.setDouble('window_height', size.height);
      await prefs.setDouble('window_x', pos.dx);
      await prefs.setDouble('window_y', pos.dy);
      debugPrint('[MiniPlayer] Persisted normal size: ${size.width}x${size.height}');
    } catch (e) {
      debugPrint('[MiniPlayer] Failed to persist normal size: $e');
    }

    state = state.copyWith(
      isPopped: true,
      viewState: MiniPlayerViewState.normal,
      originalSize: size,
      originalPosition: pos,
    );

    await Future.delayed(const Duration(milliseconds: 20));

    if (Platform.isWindows) {
      await windowManager.setHasShadow(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
      await windowManager.setMinimizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setAlwaysOnTop(true);
      
      await windowManager.setMinimumSize(const Size(250, 300));
      await windowManager.setMaximumSize(const Size(450, 550));
      await windowManager.setSize(const Size(260, 320));
    }
    
    _startIdleTimer();
  }

  Future<void> _closeMiniPlayer() async {
    _idleTimer?.cancel();

    if (Platform.isWindows) {
      // Ensure OS bounds are cleared and position is restored
      // completely BEFORE changing state to popped = false.
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(const Size(0, 0));
      await windowManager.setMaximumSize(const Size(99999, 99999));
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setMinimizable(true);
      await windowManager.setMaximizable(true);
      
      await windowManager.setMinimumSize(const Size(800, 600));

      if (state.originalSize != null) {
        await windowManager.setSize(state.originalSize!);
      }
      
      if (state.originalPosition != null) {
        await windowManager.setPosition(state.originalPosition!);
      }

      await Future.delayed(const Duration(milliseconds: 50)); // OS stabilization buffer
    }
    
    state = state.copyWith(
      isPopped: false,
      viewState: MiniPlayerViewState.normal,
    );
  }
}

final miniPlayerPopProvider = NotifierProvider<MiniPlayerPopNotifier, MiniPlayerPopState>(() {
  return MiniPlayerPopNotifier();
});
