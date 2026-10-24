import 'dart:math';
import 'package:resonance/features/library/data/models/media_item.dart';

/// Entropy and weighted sampling engine for algorithmic music recommendations.
/// Replaces static top-slicing with Efraimidis-Spirakis weighted sampling without replacement.
class RecommendationSampler {
  static final Random _defaultRng = Random();

  /// Samples [count] items from [candidates] using rank-decayed probability weights.
  /// Rank 0 has high probability, rank 10 has medium, rank 20 has exploratory probability.
  /// Excludes any tracks in [excludeIds] (such as tracks already played in session).
  static List<MediaItem> sample({
    required List<MediaItem> candidates,
    required int count,
    Set<String> excludeIds = const {},
    Random? random,
  }) {
    final rng = random ?? _defaultRng;
    final available = candidates.where((item) {
      final id = item.id ?? item.path;
      return !excludeIds.contains(id);
    }).toList();

    if (available.length <= count) {
      return available;
    }

    // Rank-decayed weight: w_i = 1.0 / (1.0 + 0.15 * i)
    // Efraimidis-Spirakis key: key = u^(1 / w_i), where u ~ Uniform(0, 1)
    final scored = <({MediaItem item, double score})>[];
    for (var i = 0; i < available.length; i++) {
      final weight = 1.0 / (1.0 + 0.15 * i);
      final u = rng.nextDouble().clamp(1e-7, 1.0);
      final key = pow(u, 1.0 / weight).toDouble();
      scored.add((item: available[i], score: key));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(count).map((e) => e.item).toList();
  }
}
