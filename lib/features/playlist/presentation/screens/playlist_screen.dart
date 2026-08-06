import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/utils/app_icons.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/application/playlist_io_helper.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_detail_screen.dart';

import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/playlist/presentation/widgets/playlist_tile.dart';

class PlaylistScreen extends ConsumerWidget {
  final bool isLocalOnly;
  const PlaylistScreen({super.key, this.isLocalOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final selectedId = ref.watch(selectedPlaylistIdProvider);
    final theme = Theme.of(context);

    if (selectedId != null) {
      return PlaylistDetailScreen(playlistId: selectedId);
    }

    if (isLocalOnly) {
      return playlistsAsync.when(
        data: (state) => _buildLocalSection(context, ref, state.local),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    }

    final currentTabIndex = ref.watch(playlistTabIndexProvider);

    return DefaultTabController(
      length: 2,
      initialIndex: currentTabIndex,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            TopNavigationHeader(
              left: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Playlists',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.label,
                        onTap: (index) => ref.read(playlistTabIndexProvider.notifier).setTabIndex(index),
                        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return theme.primaryColor.withValues(alpha: 0.08);
                          }
                          return null;
                        }),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(UIcons.regular.folder, size: 14),
                                const SizedBox(width: 6),
                                const Text('Local'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(UIcons.regular.world, size: 14),
                                const SizedBox(width: 6),
                                const Text('Stream'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              right: const SizedBox(),
            ),
            Expanded(
              child: playlistsAsync.when(
                data: (state) {
                  return TabBarView(
                    children: [
                      _buildLocalSection(context, ref, state.local),
                      _buildOnlineSection(context, ref, state),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalSection(BuildContext context, WidgetRef ref, List<Playlist> playlists) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My Local Playlists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ResonanceButton(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: AppIcons.add,
                  label: 'New',
                  style: ResonanceButtonStyle.secondary,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (playlists.isEmpty)
          _buildEmptyState(context, ref, 'No local playlists', 'Create one to organize your files.')
        else
          _buildPlaylistList(playlists),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildOnlineSection(BuildContext context, WidgetRef ref, PlaylistState state) {
    final theme = Theme.of(context);
    final playlists = state.online;
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My Stream Playlists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ReusableHoverIconButton(
                  icon: AppIcons.download,
                  tooltip: 'Import Playlist',
                  iconSize: 20,
                  onTap: () => PlaylistIOHelper.importPlaylist(context, ref),
                ),
                const SizedBox(width: 8),
                ResonanceButton(
                  onPressed: () => _showCreateDialog(context, ref, isStream: true),
                  icon: AppIcons.add,
                  label: 'New',
                  style: ResonanceButtonStyle.secondary,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (playlists.isEmpty)
          _buildEmptyState(
            context, 
            ref, 
            'No stream playlists', 
            'Create or import a playlist to organize online streaming tracks.',
            isOnline: true,
          )
        else
          _buildPlaylistList(playlists, isOnline: true),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildPlaylistList(List<Playlist> playlists, {bool isOnline = false}) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemCount: playlists.length,
        itemBuilder: (ctx, i) {
          final playlist = playlists[i];
          return PlaylistTile(playlist: playlist, isOnline: isOnline);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String title, String subtitle, {bool isOnline = false}) {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              UIcons.regular.list_music,
              size: 64,
              color: theme.hintColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
            const SizedBox(height: 24),
            ResonanceButton(
              onPressed: () => _showCreateDialog(context, ref, isStream: isOnline),
              icon: AppIcons.add,
              label: isOnline ? 'Create Stream Playlist' : 'Create Local Playlist',
              style: ResonanceButtonStyle.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, {bool isStream = false}) {
    final ctrl = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isStream ? 'New Stream Playlist' : 'New Local Playlist',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Playlist name',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    ref.read(playlistProvider.notifier).createPlaylist(v.trim(), isStream: isStream);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ResonanceButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Cancel',
                    style: ResonanceButtonStyle.secondary,
                  ),
                  const SizedBox(width: 12),
                  ResonanceButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        ref
                            .read(playlistProvider.notifier)
                            .createPlaylist(ctrl.text.trim(), isStream: isStream);
                        Navigator.pop(context);
                      }
                    },
                    label: 'Create',
                    style: ResonanceButtonStyle.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

