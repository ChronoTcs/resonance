import 'package:flutter/foundation.dart';

/// Immutable state for the Equalizer micro-domain.
@immutable
class EqualizerState {
  final List<double> bands;
  final bool isEnabled;
  final String preset;
  final bool linkSliders;

  const EqualizerState({
    this.bands = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.isEnabled = false,
    this.preset = 'Flat',
    this.linkSliders = false,
  });

  EqualizerState copyWith({
    List<double>? bands,
    bool? isEnabled,
    String? preset,
    bool? linkSliders,
  }) {
    return EqualizerState(
      bands: bands ?? this.bands,
      isEnabled: isEnabled ?? this.isEnabled,
      preset: preset ?? this.preset,
      linkSliders: linkSliders ?? this.linkSliders,
    );
  }
}
