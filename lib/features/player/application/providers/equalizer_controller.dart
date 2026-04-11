import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../services/equalizer_service.dart';
import '../../data/services/audio_persistence_service.dart';
import '../states/equalizer_state.dart';
import 'audio_provider.dart';

/// Controller for the Equalizer micro-domain.
/// Decouples DSP logic and state from the main AudioNotifier.
class EqualizerController extends Notifier<EqualizerState> {
  late EqualizerService _eqService;
  late AudioPersistenceService _persistence;
  
  Timer? _applyTimer;
  DateTime? _lastApplyTime;

  @override
  EqualizerState build() {
    _eqService = ref.read(equalizerServiceProvider);
    _persistence = ref.read(audioPersistenceServiceProvider);
    
    // Load initial settings from persistence
    final settings = _persistence.loadSettings();
    
    ref.onDispose(() {
      _applyTimer?.cancel();
    });

    return EqualizerState(
      bands: settings.equalizerBands,
      isEnabled: settings.isEqualizerEnabled,
      preset: settings.equalizerPreset,
      linkSliders: settings.linkEqualizerSliders,
    );
  }

  void toggleEqualizer(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
    _saveAndApply();
  }

  void setEqualizerBand(int index, double value) {
    if (index < 0 || index >= state.bands.length) return;
    
    final newBands = state.linkSliders
        ? _eqService.calculateLinkedBands(
            index: index,
            newValue: value,
            currentBands: state.bands,
          )
        : (List<double>.from(state.bands)..[index] = value);
        
    state = state.copyWith(bands: newBands, preset: 'Custom');
    _saveAndApply(throttled: true);
  }

  void setEqualizerPreset(String preset) {
    final bands = _eqService.getPresetBands(preset);
    state = state.copyWith(preset: preset, bands: bands);
    _saveAndApply();
  }

  void toggleLinkSliders(bool link) {
    state = state.copyWith(linkSliders: link);
    _saveAndApply();
  }

  /// Restoration entry-point for PlaybackRestorationService
  void loadSettings() {
    final s = _persistence.loadSettings();
    state = state.copyWith(
      isEnabled: s.isEqualizerEnabled,
      preset: s.equalizerPreset,
      bands: s.equalizerBands,
      linkSliders: s.linkEqualizerSliders,
    );
    _applyFilters();
  }

  void _saveAndApply({bool throttled = false}) {
    _persistence.saveEqualizerSettings(
      enabled: state.isEnabled,
      preset: state.preset,
      bands: state.bands,
      linked: state.linkSliders,
    );
    
    if (throttled) {
      _applyThrottled();
    } else {
      _applyFilters();
    }
  }

  void _applyThrottled() {
    const throttle = Duration(milliseconds: 200);
    _applyTimer?.cancel();
    
    final now = DateTime.now();
    if (_lastApplyTime == null || now.difference(_lastApplyTime!) > throttle) {
      _applyFilters();
      _lastApplyTime = now;
    } else {
      _applyTimer = Timer(throttle - now.difference(_lastApplyTime!), () {
        _applyFilters();
        _lastApplyTime = DateTime.now();
      });
    }
  }

  void _applyFilters() {
    final player = ref.read(audioProvider.notifier).player;
    if (player.platform is NativePlayer) {
      final filter = _eqService.generateFilterString(
        state.bands,
        enabled: state.isEnabled,
      );
      (player.platform as NativePlayer).setProperty('af', filter);
    }
  }
}

final equalizerControllerProvider = NotifierProvider<EqualizerController, EqualizerState>(() {
  return EqualizerController();
});
