import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/application/services/playlist_input_handler.dart';
import 'package:resonance/features/explore/data/repositories/youtube_search_repository.dart';
import 'package:resonance/features/explore/data/repositories/youtube_playlist_repository.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

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
  final Map<String, MediaItem> _selectedTracksMap = {};
  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0; // 0: Library, 1: Online (YouTube)
  String _searchQuery = '';
  Timer? _debounceTimer;

  bool _isSearchingOnline = false;
  List<MediaItem> _onlineResults = [];
  String? _onlineError;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounceTimer?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _onlineResults = [];
        _isSearchingOnline = false;
        _onlineError = null;
      });
      return;
    }

    final analysis = PlaylistInputHandler.analyze(trimmed);

    // If input is a URL (single video or playlist), auto-switch to online and resolve
    if (analysis.type == PlaylistInputType.singleTrack && analysis.videoId != null) {
      if (_selectedTab != 1) setState(() => _selectedTab = 1);
      _resolveDirectVideo(analysis.videoId!);
      return;
    } else if (analysis.type == PlaylistInputType.playlist && analysis.playlistId != null) {
      if (_selectedTab != 1) setState(() => _selectedTab = 1);
      _resolveDirectPlaylist(trimmed);
      return;
    }

    // Otherwise, if in Online tab, debounce search query
    if (_selectedTab == 1) {
      _debounceTimer = Timer(const Duration(milliseconds: 450), () {
        _performOnlineSearch(trimmed);
      });
    }
  }

  Future<void> _resolveDirectVideo(String videoId) async {
    final isOnline = ref.read(networkConnectivityProvider).isOnline;
    if (!isOnline) {
      setState(() {
        _isSearchingOnline = false;
        _onlineError = 'Cannot resolve YouTube link while offline.';
      });
      return;
    }

    setState(() {
      _isSearchingOnline = true;
      _onlineError = null;
    });

    try {
      final repo = ref.read(youtubeSearchRepositoryProvider);
      final item = await repo.fetchTrackDetails(videoId);
      if (!mounted) return;

      if (item != null) {
        final mediaItem = MediaItem(
          id: item.id,
          title: item.title,
          artist: item.author,
          thumbnailUrl: item.thumbnailUrl,
          duration: _parseDurationString(item.duration),
          path: item.id,
          type: 'audio',
        );
        setState(() {
          _onlineResults = [mediaItem];
          _isSearchingOnline = false;
        });
      } else {
        setState(() {
          _onlineResults = [];
          _isSearchingOnline = false;
          _onlineError = 'Video not found or unavailable.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingOnline = false;
        _onlineError = 'Error resolving video link: $e';
      });
    }
  }

  Future<void> _resolveDirectPlaylist(String input) async {
    final isOnline = ref.read(networkConnectivityProvider).isOnline;
    if (!isOnline) {
      setState(() {
        _isSearchingOnline = false;
        _onlineError = 'Cannot resolve YouTube playlist while offline.';
      });
      return;
    }

    setState(() {
      _isSearchingOnline = true;
      _onlineError = null;
    });

    try {
      final repo = ref.read(youtubePlaylistRepositoryProvider);
      final items = await repo.fetchFullPlaylistContents(input);
      if (!mounted) return;

      if (items.isNotEmpty) {
        final mediaItems = items.map((t) => MediaItem(
          id: t.id,
          title: t.title,
          artist: t.author,
          thumbnailUrl: t.thumbnailUrl,
          duration: _parseDurationString(t.duration),
          path: t.id,
          type: 'audio',
        )).toList();

        setState(() {
          _onlineResults = mediaItems;
          _isSearchingOnline = false;
        });
      } else {
        setState(() {
          _onlineResults = [];
          _isSearchingOnline = false;
          _onlineError = 'No tracks found in playlist.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingOnline = false;
        _onlineError = 'Error fetching playlist: $e';
      });
    }
  }

  Future<void> _performOnlineSearch(String query) async {
    final isOnline = ref.read(networkConnectivityProvider).isOnline;
    if (!isOnline) {
      setState(() {
        _isSearchingOnline = false;
        _onlineError = 'Connect to the internet to search YouTube.';
      });
      return;
    }

    setState(() {
      _isSearchingOnline = true;
      _onlineError = null;
    });

    try {
      final repo = ref.read(youtubeSearchRepositoryProvider);
      final results = await repo.search(query);
      if (!mounted) return;

      final mediaItems = results.map((e) => MediaItem(
        id: e.id,
        title: e.title,
        artist: e.author,
        thumbnailUrl: e.thumbnailUrl,
        duration: _parseDurationString(e.duration),
        path: e.id,
        type: 'audio',
      )).toList();

      setState(() {
        _onlineResults = mediaItems;
        _isSearchingOnline = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingOnline = false;
        _onlineError = 'Search failed. Please try again.';
      });
    }
  }

  Duration? _parseDurationString(String durationStr) {
    final parts = durationStr.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: m, seconds: s);
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: h, minutes: m, seconds: s);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playlistState = ref.watch(playlistProvider).value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark
        ? colorScheme.surface.withValues(alpha: 0.92)
        : colorScheme.surface.withValues(alpha: 0.96);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    // Combine local audio items and all streaming tracks across playlists
    final Map<String, MediaItem> localCandidates = {};
    for (final m in libraryState.allMedia) {
      if (m.type == 'audio') {
        localCandidates[m.id ?? m.path] = m;
      }
    }
    if (playlistState != null) {
      for (final pl in playlistState.playlists) {
        for (final t in pl.tracks) {
          localCandidates.putIfAbsent(t.id ?? t.path, () => t);
        }
      }
    }

    final query = _searchQuery.trim().toLowerCase();
    final localMusic = localCandidates.values.where((m) {
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
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      color: sheetBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                          blurRadius: 28,
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

                          // Header & Action Bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Row(
                              children: [
                                Text(
                                  'Add Music',
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                ResonanceButton(
                                  onPressed: _selectedIds.isEmpty
                                      ? null
                                      : () async {
                                          final List<MediaItem> toAdd = [];
                                          for (final id in _selectedIds) {
                                            final item = _selectedTracksMap[id] ?? localCandidates[id];
                                            if (item != null) toAdd.add(item);
                                          }
                                          if (toAdd.isNotEmpty) {
                                            await ref
                                                .read(playlistProvider.notifier)
                                                .addTracksToPlaylist(widget.playlistId, toAdd);
                                            ref.read(notificationProvider.notifier).showNotification(
                                              'Tracks Added',
                                              'Added ${toAdd.length} ${toAdd.length == 1 ? 'song' : 'songs'} to playlist.',
                                              target: 'target:playlist:${widget.playlistId}',
                                              silentOsNotification: true,
                                            );
                                          }
                                          if (context.mounted) Navigator.pop(context);
                                        },
                                  label: 'Add (${_selectedIds.length})',
                                  style: ResonanceButtonStyle.primary,
                                ),
                              ],
                            ),
                          ),

                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: _selectedTab == 0
                                    ? 'Search my music...'
                                    : 'Search YouTube or paste video/playlist link...',
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  fontSize: 13.5,
                                ),
                                prefixIcon: Icon(UIcons.regular.search, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(UIcons.regular.cross_small, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Tab Switcher: Library vs Online
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTabButton(
                                      title: 'My Library (${localMusic.length})',
                                      icon: UIcons.regular.music,
                                      isSelected: _selectedTab == 0,
                                      onTap: () {
                                        setState(() => _selectedTab = 0);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildTabButton(
                                      title: 'YouTube Online',
                                      icon: UIcons.regular.globe,
                                      isSelected: _selectedTab == 1,
                                      onTap: () {
                                        setState(() => _selectedTab = 1);
                                        if (_searchQuery.trim().isNotEmpty && _onlineResults.isEmpty) {
                                          _onSearchChanged(_searchQuery);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Track list body
                          Expanded(
                            child: _selectedTab == 0
                                ? _buildLocalMusicList(localMusic, theme)
                                : _buildOnlineMusicList(theme),
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
      );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalMusicList(List<MediaItem> music, ThemeData theme) {
    if (music.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(UIcons.regular.music, size: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? 'No music found in your library.' : 'No matching songs found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    return SilkyListView.builder(
      itemCount: music.length,
      itemBuilder: (context, index) {
        final track = music[index];
        return _buildTrackTile(track, theme);
      },
    );
  }

  Widget _buildOnlineMusicList(ThemeData theme) {
    if (_isSearchingOnline) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_onlineError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(UIcons.regular.exclamation, size: 36, color: theme.colorScheme.error),
              const SizedBox(height: 10),
              Text(
                _onlineError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }

    if (_onlineResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(UIcons.regular.search, size: 42, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35)),
              const SizedBox(height: 12),
              Text(
                'Search YouTube or paste a link',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter song titles, artist names, or paste any youtu.be / playlist link to add songs.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SilkyListView.builder(
      itemCount: _onlineResults.length,
      itemBuilder: (context, index) {
        final track = _onlineResults[index];
        return _buildTrackTile(track, theme);
      },
    );
  }

  Widget _buildTrackTile(MediaItem track, ThemeData theme) {
    final trackId = track.id ?? track.path;
    final isSelected = _selectedIds.contains(trackId);
    final alreadyInPlaylist = ref.watch(playlistProvider).value?.getById(widget.playlistId)?.tracks.any(
              (t) => (t.id ?? t.path) == trackId,
            ) ??
        false;

    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        dense: true,
        mouseCursor: alreadyInPlaylist ? SystemMouseCursors.basic : SystemMouseCursors.click,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        value: isSelected || alreadyInPlaylist,
        onChanged: alreadyInPlaylist
            ? null
            : (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.add(trackId);
                    _selectedTracksMap[trackId] = track;
                  } else {
                    _selectedIds.remove(trackId);
                    _selectedTracksMap.remove(trackId);
                  }
                });
              },
        title: Row(
          children: [
            Expanded(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: alreadyInPlaylist
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (alreadyInPlaylist) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'IN PLAYLIST',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ] else if (track.isStreaming) ...[
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
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          track.artist ?? 'Unknown Artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: alreadyInPlaylist ? 0.4 : 0.8),
          ),
        ),
        secondary: MediaArtworkWidget(
          item: track,
          width: 42,
          height: 42,
          borderRadius: 6,
        ),
      ),
    );
  }
}
