import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/data/services/storage_service.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SleepTimerMode { none, duration, endOfTrack }

class SleepTimerState {
  final bool isEnabled;
  final SleepTimerMode selectedMode;
  final Duration selectedDuration;
  final Duration remainingDuration;
  final Duration totalDuration;
  final bool isFadingOut;
  final bool fadeOutEnabled;
  final double? preFadeVolume;

  const SleepTimerState({
    this.isEnabled = false,
    this.selectedMode = SleepTimerMode.duration,
    this.selectedDuration = const Duration(minutes: 30),
    this.remainingDuration = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isFadingOut = false,
    this.fadeOutEnabled = true,
    this.preFadeVolume,
  });

  /// True when the timer is armed and actively running.
  bool get isActive => isEnabled;

  /// Effective active mode. Returns [SleepTimerMode.none] when disabled.
  SleepTimerMode get mode => isEnabled ? selectedMode : SleepTimerMode.none;

  bool get isEndOfTrack => isEnabled && selectedMode == SleepTimerMode.endOfTrack;
  bool get isDurationMode => isEnabled && selectedMode == SleepTimerMode.duration;

  SleepTimerState copyWith({
    bool? isEnabled,
    SleepTimerMode? selectedMode,
    Duration? selectedDuration,
    Duration? remainingDuration,
    Duration? totalDuration,
    bool? isFadingOut,
    bool? fadeOutEnabled,
    double? preFadeVolume,
    bool clearPreFadeVolume = false,
  }) {
    return SleepTimerState(
      isEnabled: isEnabled ?? this.isEnabled,
      selectedMode: selectedMode ?? this.selectedMode,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      isFadingOut: isFadingOut ?? this.isFadingOut,
      fadeOutEnabled: fadeOutEnabled ?? this.fadeOutEnabled,
      preFadeVolume: clearPreFadeVolume ? null : (preFadeVolume ?? this.preFadeVolume),
    );
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  static const String _kDurationMinutesKey = 'sleep_timer_duration_minutes';
  static const String _kModeKey = 'sleep_timer_mode';
  static const String _kFadeOutKey = 'sleep_timer_fade_out';

  Timer? _ticker;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });

    SharedPreferences? prefs;
    try {
      prefs = ref.watch(sharedPreferencesProvider);
    } catch (_) {}

    final savedMinutes = prefs?.getInt(_kDurationMinutesKey) ?? 30;
    final savedModeStr = prefs?.getString(_kModeKey) ?? 'duration';
    final savedFadeOut = prefs?.getBool(_kFadeOutKey) ?? true;

    final mode = savedModeStr == 'endOfTrack' ? SleepTimerMode.endOfTrack : SleepTimerMode.duration;

    return SleepTimerState(
      isEnabled: false,
      selectedMode: mode,
      selectedDuration: Duration(minutes: savedMinutes),
      fadeOutEnabled: savedFadeOut,
    );
  }

  void _savePreferences() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setInt(_kDurationMinutesKey, state.selectedDuration.inMinutes);
      prefs.setString(
        _kModeKey,
        state.selectedMode == SleepTimerMode.endOfTrack ? 'endOfTrack' : 'duration',
      );
      prefs.setBool(_kFadeOutKey, state.fadeOutEnabled);
    } catch (_) {}
  }

  /// Selects a duration preset without necessarily activating it immediately.
  /// If the timer is already active, restarts the countdown with the new duration.
  void selectDuration(Duration duration) {
    if (state.isEnabled) {
      setDuration(duration);
    } else {
      state = state.copyWith(
        selectedMode: SleepTimerMode.duration,
        selectedDuration: duration,
      );
      _savePreferences();
    }
  }

  /// Selects the End-of-Track mode preset.
  /// If the timer is already active, immediately switches to End-of-Track mode.
  void selectEndOfTrack() {
    if (state.isEnabled) {
      setEndOfTrack();
    } else {
      state = state.copyWith(
        selectedMode: SleepTimerMode.endOfTrack,
      );
      _savePreferences();
    }
  }

  /// Activates or deactivates the Sleep Timer feature using the configured preset.
  void setEnabled(bool enabled) {
    if (enabled) {
      if (state.selectedMode == SleepTimerMode.endOfTrack) {
        setEndOfTrack();
      } else {
        setDuration(state.selectedDuration);
      }
    } else {
      deactivate();
    }
  }

  /// Explicitly activates the sleep timer.
  void activate() => setEnabled(true);

  /// Explicitly deactivates the sleep timer, stopping countdown and restoring volume if fading.
  void deactivate() {
    _ticker?.cancel();
    _restoreVolumeIfFading();
    state = state.copyWith(
      isEnabled: false,
      remainingDuration: Duration.zero,
      totalDuration: Duration.zero,
      isFadingOut: false,
      clearPreFadeVolume: true,
    );
  }

  /// Sets and activates a duration-based countdown timer.
  void setDuration(Duration duration, {bool? fadeOut}) {
    _ticker?.cancel();
    _restoreVolumeIfFading();

    final fade = fadeOut ?? state.fadeOutEnabled;
    state = state.copyWith(
      isEnabled: true,
      selectedMode: SleepTimerMode.duration,
      selectedDuration: duration,
      remainingDuration: duration,
      totalDuration: duration,
      fadeOutEnabled: fade,
      isFadingOut: false,
      clearPreFadeVolume: true,
    );
    _savePreferences();

    _ticker = Timer.periodic(const Duration(seconds: 1), _onDurationTick);
  }

  /// Sets and activates the End-of-Track timer mode.
  void setEndOfTrack({bool? fadeOut}) {
    _ticker?.cancel();
    _restoreVolumeIfFading();

    final fade = fadeOut ?? state.fadeOutEnabled;
    state = state.copyWith(
      isEnabled: true,
      selectedMode: SleepTimerMode.endOfTrack,
      remainingDuration: Duration.zero,
      totalDuration: Duration.zero,
      fadeOutEnabled: fade,
      isFadingOut: false,
      clearPreFadeVolume: true,
    );
    _savePreferences();

    if (fade) {
      _ticker = Timer.periodic(const Duration(seconds: 1), _onEndOfTrackTick);
    }
  }

  /// Toggles or updates the volume fade-out preference.
  void setFadeOut(bool enabled) {
    state = state.copyWith(fadeOutEnabled: enabled);
    _savePreferences();
  }

  /// Adds extra minutes to an active duration timer.
  void addMinutes(int minutes) {
    if (!state.isDurationMode) return;
    final extra = Duration(minutes: minutes);
    final newRemaining = state.remainingDuration + extra;
    final newTotal = state.totalDuration + extra;

    // If volume was already fading out, restore it since timer was extended
    _restoreVolumeIfFading();

    state = state.copyWith(
      remainingDuration: newRemaining,
      totalDuration: newTotal,
      isFadingOut: false,
      clearPreFadeVolume: true,
    );
  }

  /// Cancels / deactivates the sleep timer.
  void cancel() => deactivate();

  /// Invoked when the current track legitimately ends while [isEndOfTrack] is armed.
  void triggerEndOfTrackStop() {
    _ticker?.cancel();
    _restoreVolumeIfFading();
    state = state.copyWith(
      isEnabled: false,
      remainingDuration: Duration.zero,
      totalDuration: Duration.zero,
      isFadingOut: false,
      clearPreFadeVolume: true,
    );
    try {
      ref.read(notificationProvider.notifier).showNotification(
        'Sleep Timer',
        'Playback paused at end of track.',
        silentOsNotification: true,
      );
    } catch (_) {}
  }

  void _onDurationTick(Timer timer) {
    if (!state.isDurationMode) {
      timer.cancel();
      return;
    }

    final newRemaining = state.remainingDuration - const Duration(seconds: 1);
    if (newRemaining <= Duration.zero) {
      timer.cancel();
      _executePause();
      return;
    }

    if (state.fadeOutEnabled && newRemaining.inSeconds <= 10) {
      _performFadeStep(newRemaining.inSeconds);
    }

    state = state.copyWith(remainingDuration: newRemaining);
  }

  void _onEndOfTrackTick(Timer timer) {
    if (!state.isEndOfTrack) {
      timer.cancel();
      return;
    }

    final audioState = ref.read(audioProvider);
    final dur = audioState.duration;
    final pos = audioState.position;

    if (dur > Duration.zero && dur > pos) {
      final remaining = (dur - pos).inSeconds;
      if (remaining <= 10 && remaining >= 0) {
        _performFadeStep(remaining);
      }
    }
  }

  void _performFadeStep(int remainingSeconds) {
    final audioNotifier = ref.read(audioProvider.notifier);
    final currentVolume = ref.read(audioProvider).volume;

    final initialVol = state.preFadeVolume ?? (currentVolume > 0 ? currentVolume : 100.0);
    final targetVol = (initialVol * (remainingSeconds / 10.0)).clamp(0.0, 100.0);

    state = state.copyWith(
      isFadingOut: true,
      preFadeVolume: initialVol,
    );
    audioNotifier.setVolume(targetVol);
  }

  void _executePause() {
    final audioNotifier = ref.read(audioProvider.notifier);
    audioNotifier.pause();
    _restoreVolumeIfFading();
    state = state.copyWith(
      isEnabled: false,
      remainingDuration: Duration.zero,
      totalDuration: Duration.zero,
      isFadingOut: false,
      clearPreFadeVolume: true,
    );

    try {
      ref.read(notificationProvider.notifier).showNotification(
        'Sleep Timer',
        'Playback paused by sleep timer.',
        silentOsNotification: true,
      );
    } catch (_) {}
  }

  void _restoreVolumeIfFading() {
    if (state.preFadeVolume != null) {
      try {
        ref.read(audioProvider.notifier).setVolume(state.preFadeVolume!);
      } catch (e) {
        debugPrint('[SleepTimer] Failed to restore pre-fade volume: $e');
      }
    }
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState>(() {
  return SleepTimerNotifier();
});
