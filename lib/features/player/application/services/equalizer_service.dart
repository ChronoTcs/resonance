import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Preset Definitions ────────────────────────────────────────────────────────

/// All available equalizer presets.
/// Band order corresponds to frequencies: [62.5, 125, 250, 500, 1k, 2k, 4k, 8k, 16k] Hz
const Map<String, List<double>> kEqualizerPresets = {
  'Flat':           [ 0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0],
  'Bass Boost':     [ 6.0,  4.5,  3.0,  1.0,  0.0,  0.0,  0.0,  0.0,  0.0],
  'Deep Bass':      [ 8.0,  6.0,  3.5,  1.0,  0.0,  0.0,  0.0,  0.0,  0.0],
  'Sub Bass':       [ 9.0,  5.0,  1.0, -1.0,  0.0,  0.0,  0.0,  0.0,  0.0],
  'Bass Reducer':   [-6.0, -4.0, -2.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0],
  'Treble Boost':   [ 0.0,  0.0,  0.0,  0.0,  0.0,  2.0,  4.0,  6.0,  7.0],
  'Treble Reducer': [ 0.0,  0.0,  0.0,  0.0,  0.0, -2.0, -4.0, -6.0, -7.0],
  'Vocal Booster':  [-2.0, -1.0,  0.0,  2.5,  4.5,  4.0,  2.0,  0.0, -2.0],
  'Vocal':          [-2.0, -1.0,  0.0,  2.5,  4.5,  4.0,  2.0,  0.0, -2.0], // Backwards-compatible alias
  'Spoken Word':    [-4.0, -2.0,  0.0,  2.0,  4.0,  3.0,  1.0, -1.0, -3.0],
  'Rock':           [ 4.5,  3.0,  0.0, -1.0, -1.0,  1.0,  3.0,  4.5,  4.5],
  'Pop':            [-1.0,  1.0,  3.0,  3.5,  2.0,  0.0,  1.0,  2.5,  2.0],
  'Hip Hop':        [ 6.0,  5.0,  2.0,  0.0, -1.0,  1.0,  2.0,  3.0,  3.5],
  'R&B':            [ 5.0,  4.0,  1.0, -1.0,  1.0,  2.0,  3.0,  4.0,  3.5],
  'Dance':          [ 5.5,  4.5,  2.0,  0.0,  1.0,  2.5,  4.0,  3.5,  2.5],
  'Electronic':     [ 4.5,  4.0,  1.0, -1.5,  0.0,  2.5,  4.0,  4.5,  3.5],
  'Metal':          [ 5.0,  3.5,  0.0, -2.0, -2.0,  1.0,  4.0,  5.5,  5.0],
  'Jazz':           [ 3.0,  2.0,  1.0,  1.5, -1.0, -1.0,  0.5,  1.5,  2.5],
  'Classical':      [ 4.0,  3.0,  2.0,  0.0,  0.0,  0.0,  2.0,  3.5,  4.0],
  'Acoustic':       [ 3.5,  2.5,  1.0,  1.0,  1.5,  2.0,  3.0,  3.5,  3.0],
  'Piano':          [ 2.5,  2.0,  0.0,  1.5,  2.5,  2.0,  2.5,  3.0,  2.5],
  'Lounge':         [-2.0, -1.0,  1.0,  2.0,  3.0,  1.0,  0.0,  2.0,  1.0],
  'Latin':          [ 3.0,  2.0,  0.0,  0.0,  2.0,  2.0,  3.0,  4.0,  3.5],
  'Custom':         [ 0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0],
};

/// Preset categories for organized grouping in the picker modal
const Map<String, List<String>> kEqualizerPresetCategories = {
  'General': ['Flat', 'Custom'],
  'Bass': ['Bass Boost', 'Deep Bass', 'Sub Bass', 'Bass Reducer'],
  'Voice & Speech': ['Vocal Booster', 'Spoken Word', 'Treble Boost', 'Treble Reducer'],
  'Music Genres': ['Hip Hop', 'R&B', 'Rock', 'Pop', 'Dance', 'Electronic', 'Metal'],
  'Acoustic & Instruments': ['Acoustic', 'Classical', 'Jazz', 'Piano', 'Lounge', 'Latin'],
};

/// Popular presets shown in the quick horizontal chip carousel
const List<String> kPopularEqualizerPresets = [
  'Flat',
  'Bass Boost',
  'Deep Bass',
  'Vocal Booster',
  'Rock',
  'Pop',
  'Hip Hop',
  'R&B',
  'Electronic',
  'Acoustic',
  'Classical',
  'Jazz',
];

/// Frequencies for the 9-band equalizer (used in FFmpeg filter string)
const List<double> kEqualizerFrequencies = [
  62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
];

// ── Service ───────────────────────────────────────────────────────────────────

/// Pure DSP calculation service. Does NOT hold any reference to media_kit Player.
/// All outputs are data structures/strings which the AudioNotifier applies.
class EqualizerService {
  const EqualizerService();

  /// Returns the preset bands for a given preset name.
  /// Falls back to 'Flat' if the preset is unknown.
  List<double> getPresetBands(String preset) {
    return List<double>.from(
      kEqualizerPresets[preset] ?? kEqualizerPresets['Flat']!,
    );
  }

  /// Returns a list of all available preset names.
  List<String> get allPresets => kEqualizerPresets.keys.toList();

  /// Calculates the new band values when a single band is adjusted with
  /// the "Linked Sliders" feature enabled.
  /// 
  /// - 1st neighbors receive 50% of the delta.
  /// - 2nd neighbors receive 25% of the delta.
  List<double> calculateLinkedBands({
    required int index,
    required double newValue,
    required List<double> currentBands,
  }) {
    final bands = List<double>.from(currentBands);
    final diff = newValue - bands[index];
    bands[index] = newValue;

    // 1st Neighbors: 50% effect
    if (index > 0) {
      bands[index - 1] = (bands[index - 1] + diff * 0.5).clamp(-12.0, 12.0);
    }
    if (index < bands.length - 1) {
      bands[index + 1] = (bands[index + 1] + diff * 0.5).clamp(-12.0, 12.0);
    }

    // 2nd Neighbors: 25% effect
    if (index > 1) {
      bands[index - 2] = (bands[index - 2] + diff * 0.25).clamp(-12.0, 12.0);
    }
    if (index < bands.length - 2) {
      bands[index + 2] = (bands[index + 2] + diff * 0.25).clamp(-12.0, 12.0);
    }

    return bands;
  }

  /// Generates the FFmpeg `af` filter string for mpv's setProperty.
  /// Returns an empty string if EQ is disabled or all bands are zero.
  ///
  /// The AudioNotifier is responsible for calling:
  /// `(player.platform as NativePlayer).setProperty('af', filterString)`
  String generateFilterString(List<double> bands, {required bool enabled}) {
    if (!enabled) return '';

    final afParts = <String>[];
    for (int i = 0; i < bands.length && i < kEqualizerFrequencies.length; i++) {
      if (bands[i] != 0.0) {
        afParts.add(
          'equalizer=f=${kEqualizerFrequencies[i]}:width_type=o:w=1:g=${bands[i]}',
        );
      }
    }
    return afParts.join(',');
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Stateless provider — EqualizerService is a pure calculation engine.
final equalizerServiceProvider = Provider<EqualizerService>((ref) {
  return const EqualizerService();
});
