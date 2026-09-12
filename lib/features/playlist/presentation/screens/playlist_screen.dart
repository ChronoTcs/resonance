import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/playlist/data/models/playlist_model.dart';
import 'package:resonance/features/playlist/application/playlist_provider.dart';
import 'package:resonance/features/playlist/application/playlist_io_helper.dart';
import 'package:resonance/features/playlist/presentation/screens/playlist_detail_screen.dart';

import 'package:resonance/features/dashboard/presentation/widgets/top_navigation_header.dart';
import 'package:resonance/features/playlist/presentation/widgets/playlist_tile.dart';

class PlaylistScreen extends ConsumerWidget {
  final bool showHeader;

  const PlaylistScreen({
    super.key,
    this.showHeader = true,
    // Backward-compat params kept as no-ops so call-sites don't need updates
    // ignore: unused_element
    bool isLocalOnly = false,
    // ignore: unused_element
    bool isStreamOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final selectedId = ref.watch(selectedPlaylistIdProvider);
    final theme = Theme.of(context);

    if (selectedId != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ref.read(selectedPlaylistIdProvider.notifier).setSelectedId(null);
          }
        },
        child: PlaylistDetailScreen(playlistId: selectedId),
      );
    }

    final content = playlistsAsync.when(
      data: (state) => _buildUnifiedList(context, ref, state.playlists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );

    if (!showHeader) return content;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          const OfflineBanner(),
          TopNavigationHeader(
            left: Text(
              'Playlists',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            right: _PlaylistHeaderToolbar(
              onImport: () => PlaylistIOHelper.importPlaylist(context, ref),
              onNew: () => _showCreateDialog(context, ref),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildUnifiedList(BuildContext context, WidgetRef ref, List<Playlist> playlists) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        if (!showHeader) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SizedBox(
                height: 36,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Playlists',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _PlaylistHeaderToolbar(
                      onImport: () => PlaylistIOHelper.importPlaylist(context, ref),
                      onNew: () => _showCreateDialog(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (playlists.isEmpty)
          _PlaylistEmptyState(onCreate: () => _showCreateDialog(context, ref))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: playlists.length,
              itemBuilder: (ctx, i) => PlaylistTile(playlist: playlists[i]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _CreatePlaylistDialog(
        onConfirm: (name) => ref.read(playlistProvider.notifier).createPlaylist(name),
      ),
    );
  }
}

class _PlaylistHeaderToolbar extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onNew;

  const _PlaylistHeaderToolbar({
    required this.onImport,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReusableHoverIconButton(
          icon: UIcons.regular.download,
          tooltip: 'Import Playlist',
          iconSize: 18,
          padding: 6,
          onTap: onImport,
        ),
        const SizedBox(width: 8),
        ResonanceButton(
          onPressed: onNew,
          icon: UIcons.regular.add,
          label: 'New',
          style: ResonanceButtonStyle.secondary,
        ),
      ],
    );
  }
}

class _PlaylistEmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _PlaylistEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
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
              'No playlists yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Create a playlist to organize your local and streaming music.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
            const SizedBox(height: 24),
            ResonanceButton(
              onPressed: onCreate,
              icon: UIcons.regular.add,
              label: 'Create Playlist',
              style: ResonanceButtonStyle.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  final ValueChanged<String> onConfirm;

  const _CreatePlaylistDialog({required this.onConfirm});

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isNotEmpty) {
      widget.onConfirm(text);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Playlist',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
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
                  onSubmitted: (_) => _submit(),
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
                      onPressed: _submit,
                      label: 'Create',
                      style: ResonanceButtonStyle.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
