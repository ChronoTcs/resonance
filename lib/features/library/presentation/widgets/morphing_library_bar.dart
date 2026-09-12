import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/layout/resonance_segmented_bar.dart';

enum LibraryNavMode {
  music,
  playlists,
  downloads,
}

class LibraryNavModeNotifier extends Notifier<LibraryNavMode> {
  @override
  LibraryNavMode build() => LibraryNavMode.music;

  void setMode(LibraryNavMode mode) => state = mode;
}

final libraryNavModeProvider =
    NotifierProvider<LibraryNavModeNotifier, LibraryNavMode>(
  LibraryNavModeNotifier.new,
);

/// A clean, modern morphing segmented bar for mobile library navigation.
///
/// Automatically morphs between:
/// - 2 items (Music & Playlists) at 50/50 split
/// - 3 items (Music, Playlists, Downloads) at 33.3% split when Downloads is active
class MorphingLibraryBar extends StatelessWidget {
  final LibraryNavMode currentMode;
  final ValueChanged<LibraryNavMode> onModeChanged;

  const MorphingLibraryBar({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  bool get isDownloadsMode => currentMode == LibraryNavMode.downloads;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = currentMode == LibraryNavMode.music
        ? 0
        : (currentMode == LibraryNavMode.playlists ? 1 : 2);

    final items = [
      ResonanceSegmentItem(
        label: 'Music',
        icon: UIcons.regular.music,
      ),
      ResonanceSegmentItem(
        label: 'Playlists',
        icon: UIcons.regular.list_music,
      ),
      if (isDownloadsMode)
        ResonanceSegmentItem(
          label: '',
          icon: UIcons.regular.download,
          tooltip: 'Downloads',
          isDismissible: true,
          onDismiss: () => onModeChanged(LibraryNavMode.music),
        ),
    ];

    return ResonanceSegmentedBar(
      items: items,
      selectedIndex: selectedIndex,
      onSelected: (index) {
        if (index == 0) {
          onModeChanged(LibraryNavMode.music);
        } else if (index == 1) {
          onModeChanged(LibraryNavMode.playlists);
        } else {
          onModeChanged(LibraryNavMode.downloads);
        }
      },
    );
  }
}
