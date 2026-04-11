import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/data/services/storage_service.dart';
import '../models/player_enums.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kVolume = 'audio_volume';
const _kSpeed = 'audio_speed';
const _kPitch = 'audio_pitch';
const _kEqEnabled = 'audio_eq_enabled';
const _kEqPreset = 'audio_eq_preset';
const _kEqBands = 'audio_eq_bands';
const _kEqLinked = 'audio_eq_linked';
const _kLoopMode = 'audio_loop_mode';
const _kShuffle = 'audio_shuffle';

// -- Playback State Keys (V16.1) --
const _kLastTrack = 'audio_last_track';
const _kLastQueue = 'audio_last_queue';
const _kLastIndex = 'audio_last_index';
const _kLastPosition = 'audio_last_position';

// ── Data Model ────────────────────────────────────────────────────────────────

/// Snapshot of all persisted audio settings loaded at startup.
class AudioPersistedSettings {
  final double volume;
  final double speed;
  final double pitch;
  final bool isEqualizerEnabled;
  final String equalizerPreset;
  final List<double> equalizerBands;
  final bool linkEqualizerSliders;
  final LoopMode loopMode;
  final bool isShuffleEnabled;

  // -- Playback State (V16.1) --
  final String? lastTrackJson;
  final List<String>? lastQueueJson;
  final int lastIndex;
  final int lastPositionMs;

  const AudioPersistedSettings({
    this.volume = 100.0,
    this.speed = 1.0,
    this.pitch = 0.0,
    this.isEqualizerEnabled = false,
    this.equalizerPreset = 'Flat',
    this.equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.linkEqualizerSliders = false,
    this.loopMode = LoopMode.off,
    this.isShuffleEnabled = false,
    this.lastTrackJson,
    this.lastQueueJson,
    this.lastIndex = -1,
    this.lastPositionMs = 0,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Responsible for all SharedPreferences I/O for the audio player.
/// Does NOT hold any reference to the media_kit Player.
/// Uses debouncing internally to prevent write-flooding during rapid changes.
class AudioPersistenceService {
  final SharedPreferences _prefs;

  final Map<String, Timer> _saveTimers = {};

  AudioPersistenceService(this._prefs);

  // ── Load ───────────────────────────────────────────────────────────────────

  AudioPersistedSettings loadSettings() {
    final volume = _prefs.getDouble(_kVolume) ?? 100.0;
    final speed = _prefs.getDouble(_kSpeed) ?? 1.0;
    final pitch = _prefs.getDouble(_kPitch) ?? 0.0;
    final eqEnabled = _prefs.getBool(_kEqEnabled) ?? false;
    final eqPreset = _prefs.getString(_kEqPreset) ?? 'Flat';
    final eqLinked = _prefs.getBool(_kEqLinked) ?? false;

    List<double> eqBands = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final savedBands = _prefs.getStringList(_kEqBands);
    if (savedBands != null && savedBands.length == 9) {
      eqBands = savedBands.map((s) => double.tryParse(s) ?? 0.0).toList();
    }

    final loopIndex = _prefs.getInt(_kLoopMode) ?? 0;
    final loopMode = LoopMode.values[loopIndex.clamp(0, LoopMode.values.length - 1)];
    final shuffle = _prefs.getBool(_kShuffle) ?? false;

    // -- Playback State (V16.1) --
    final lastTrack = _prefs.getString(_kLastTrack);
    final lastQueue = _prefs.getStringList(_kLastQueue);
    final lastIndex = _prefs.getInt(_kLastIndex) ?? -1;
    final lastPos = _prefs.getInt(_kLastPosition) ?? 0;

    return AudioPersistedSettings(
      volume: volume,
      speed: speed,
      pitch: pitch,
      isEqualizerEnabled: eqEnabled,
      equalizerPreset: eqPreset,
      equalizerBands: eqBands,
      linkEqualizerSliders: eqLinked,
      loopMode: loopMode,
      isShuffleEnabled: shuffle,
      lastTrackJson: lastTrack,
      lastQueueJson: lastQueue,
      lastIndex: lastIndex,
      lastPositionMs: lastPos,
    );
  }

  // ── Save (Debounced) ───────────────────────────────────────────────────────

  /// General-purpose debounced save. Each key has its own independent timer (V16.1 Hotfix).
  void _scheduleSave(String key, dynamic value) {
    _saveTimers[key]?.cancel();
    _saveTimers[key] = Timer(const Duration(milliseconds: 500), () {
      _write(key, value);
      _saveTimers.remove(key);
    });
  }

  void _write(String key, dynamic value) {
    if (value is double) {
      _prefs.setDouble(key, value);
    } else if (value is bool) {
      _prefs.setBool(key, value);
    } else if (value is String) {
      _prefs.setString(key, value);
    } else if (value is int) {
      _prefs.setInt(key, value);
    } else if (value is List<String>) {
      _prefs.setStringList(key, value);
    }
  }

  void saveVolume(double volume) => _scheduleSave(_kVolume, volume);
  void saveSpeed(double speed) => _scheduleSave(_kSpeed, speed);
  void savePitch(double pitch) => _scheduleSave(_kPitch, pitch);

  void saveEqualizerSettings({
    required bool enabled,
    required String preset,
    required List<double> bands,
    required bool linked,
  }) {
    // These are batched via _saveTimer; we fire immediately then let next
    // call cancel if needed.
    _prefs.setBool(_kEqEnabled, enabled);
    _prefs.setString(_kEqPreset, preset);
    _prefs.setStringList(_kEqBands, bands.map((e) => e.toString()).toList());
    _prefs.setBool(_kEqLinked, linked);
  }

  void saveLoopMode(LoopMode mode) {
    _prefs.setInt(_kLoopMode, mode.index);
  }

  void saveShuffle(bool enabled) {
    _prefs.setBool(_kShuffle, enabled);
  }

  // -- Playback Persistence (V16.1) --

  /// Persists the full playback context. Limit queue to 200 items as per V16.1 SOTA.
  void savePlaybackState({
    required String trackJson,
    required List<String> queueJson,
    required int index,
  }) {
    _prefs.setString(_kLastTrack, trackJson);
    
    // V16.1 Hotfix: Remove limit since albumArtBase64 is stripped from JSON
    _prefs.setStringList(_kLastQueue, queueJson);
    
    _prefs.setInt(_kLastIndex, index);
  }

  void savePosition(int milliseconds) {
    // Seek position changes very often, so we use the internal debouncing timer
    _scheduleSave(_kLastPosition, milliseconds);
  }

  void dispose() {
    for (var timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final audioPersistenceServiceProvider = Provider<AudioPersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = AudioPersistenceService(prefs);
  ref.onDispose(service.dispose);
  return service;
});
