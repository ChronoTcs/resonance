import 'dart:ui';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';

import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';

class MusicPickerSheet extends ConsumerStatefulWidget {
  final String playlistId;
  const MusicPickerSheet({super.key, required this.playlistId});

  static void show(BuildContext context, String playlistId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => MusicPickerSheet(playlistId: playlistId),
    );
  }

  @override
  ConsumerState<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends ConsumerState<MusicPickerSheet> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playlistState = ref.watch(playlistProvider).value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark
        ? colorScheme.surface.withValues(alpha: 0.90)
        : colorScheme.surface.withValues(alpha: 0.95);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    // Combine local audio items and all streaming tracks across playlists
    final Map<String, MediaItem> allCandidates = {};
    for (final m in libraryState.allMedia) {
      if (m.type == 'audio') {
        allCandidates[m.id ?? m.path] = m;
      }
    }
    if (playlistState != null) {
      for (final pl in playlistState.playlists) {
        for (final t in pl.tracks) {
          allCandidates.putIfAbsent(t.id ?? t.path, () => t);
        }
      }
    }

    final query = _searchQuery.trim().toLowerCase();
    final music = allCandidates.values.where((m) {
      if (query.isEmpty) return true;
      final title = m.title.toLowerCase();
      final artist = m.artist?.toLowerCase() ?? '';
      return title.contains(query) || artist.contains(query);
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () {},
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.82,
                      decoration: BoxDecoration(
                        color: sheetBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Pill drag handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
              children: [
                Text('Add to Playlist', style: theme.textTheme.titleLarge),
                const Spacer(),
                ResonanceButton(
                  onPressed: _selectedIds.isEmpty ? null : () async {
                    final selectedTracks = allCandidates.values
                        .where((m) => _selectedIds.contains(m.id ?? m.path))
                        .toList();
                    await ref.read(playlistProvider.notifier).addTracksToPlaylist(widget.playlistId, selectedTracks);
                    if (context.mounted) Navigator.pop(context);
                  },
                  label: 'Add (${_selectedIds.length})',
                  style: ResonanceButtonStyle.primary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search my music...',
                prefixIcon: Icon(UIcons.regular.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SilkyListView.builder(
              itemCount: music.length,
              itemBuilder: (context, index) {
                final track = music[index];
                final trackId = track.id ?? track.path;
                final isSelected = _selectedIds.contains(trackId);
                final alreadyInPlaylist = ref.read(playlistProvider.notifier).isTrackInPlaylist(widget.playlistId, track);

                return Material(
                  color: Colors.transparent,
                  child: Theme(
                    data: theme.copyWith(
                      checkboxTheme: CheckboxThemeData(
                        splashRadius: 18,
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                            return theme.colorScheme.onSurface.withValues(alpha: 0.08);
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return theme.colorScheme.onSurface.withValues(alpha: 0.16);
                          }
                          return null;
                        }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    child: CheckboxListTile(
                      mouseCursor: alreadyInPlaylist ? SystemMouseCursors.basic : SystemMouseCursors.click,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      value: isSelected || alreadyInPlaylist,
                      onChanged: alreadyInPlaylist ? null : (v) {
                        setState(() {
                          if (v == true) {
                            _selectedIds.add(trackId);
                          } else {
                            _selectedIds.remove(trackId);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (track.isStreaming) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'STREAM',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(track.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis),
                      secondary: MediaArtworkWidget(
                        item: track,
                        width: 40,
                        height: 40,
                        borderRadius: 4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
),
),
),
),
),
),
);
}
}

