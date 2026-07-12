import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';

class HomeNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final homeNavigationProvider = NotifierProvider<HomeNavigationNotifier, int>(() {
  return HomeNavigationNotifier();
});

class SelectedHomePlaylistNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSelectedId(String? id) {
    state = id;
  }
}

final selectedHomePlaylistProvider = NotifierProvider<SelectedHomePlaylistNotifier, String?>(() {
  return SelectedHomePlaylistNotifier();
});

/// Caches and preserves a set of 10 tracks randomly (re-evaluated only when library content changes)
final homeQuickPicksProvider = Provider<List<MediaItem>>((ref) {
  final library = ref.watch(libraryProvider);
  final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();
  if (audioTracks.isEmpty) return [];
  
  final quickPicks = List<MediaItem>.from(audioTracks)..shuffle(Random(42)); // Seeded to avoid shifting on hot-reload
  return quickPicks.take(10).toList();
});

/// Computes sorted A-Z groupings of media items by artist name
final groupedArtistsProvider = Provider<Map<String, List<MediaItem>>>((ref) {
  final library = ref.watch(libraryProvider);
  final audioTracks = library.allMedia.where((m) => m.type == 'audio').toList();

  final Map<String, List<MediaItem>> artistGroup = {};
  for (var track in audioTracks) {
    final rawArtist = track.artist;
    if (rawArtist == null || rawArtist.isEmpty) {
      artistGroup.putIfAbsent('Unknown Artist', () => []).add(track);
      continue;
    }

    final parts = rawArtist.split(RegExp(r'[,;]|\s+&\s+|\s+feat\.?\s+|\s+ft\.?\s+', caseSensitive: false));
    final addedArtists = <String>{};
    for (var part in parts) {
      final name = part.trim();
      if (name.isNotEmpty) {
        if (addedArtists.add(name)) {
          artistGroup.putIfAbsent(name, () => []).add(track);
        }
      }
    }
    if (addedArtists.isEmpty) {
      artistGroup.putIfAbsent('Unknown Artist', () => []).add(track);
    }
  }
  return artistGroup;
});
