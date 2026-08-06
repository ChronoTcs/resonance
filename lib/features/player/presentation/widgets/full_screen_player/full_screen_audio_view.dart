import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';

import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/shared/audio_settings_sheet.dart';
import 'package:resonance/features/player/presentation/widgets/player_cards.dart';

/// [FullScreenAudioView]
/// Responsible ONLY for Audio mode layout:
/// - SliverAppBar (Title + Actions)
/// - Album Artwork with shadow & Hero animation
/// - Metadata Cards (MetadataCard + NextInQueueCard + MiniLyricsCard)
class FullScreenAudioView extends ConsumerWidget {
  final dynamic displayTrack;

  const FullScreenAudioView({super.key, required this.displayTrack});

  void _showMediaActions(BuildContext context, WidgetRef ref, dynamic track) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MediaActionsBottomSheet(
        item: track,
        onDelete: track.id == null
            ? () => _confirmDelete(context, ref, track)
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (dlg) => ResonanceConfirmDialog(
        title: 'Delete Track',
        content: 'Permanently delete "${item.title}" from your device? This cannot be undone.',
        confirmLabel: 'Delete',
        isDanger: true,
        onConfirm: () {
          ref.read(libraryProvider.notifier).deleteTrack(item.path);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${item.title}" deleted.')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Base: Scrollable Audio Content
        Positioned.fill(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAudioAppBar(context, ref, theme),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: screenHeight * 0.55),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _buildAudioArtwork(),
                      ),
                    ),
                  ),
                ),
              ),
              _buildAudioMetadataSection(),
              const SliverToBoxAdapter(child: SizedBox(height: 200)),
            ],
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAudioAppBar(BuildContext context, WidgetRef ref, ThemeData theme) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: false,
      leadingWidth: 200,
      leading: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            Text(
              'Playing Now',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ReusableHoverIconButton(
          icon: UIcons.regular.add,
          color: Colors.white70,
          tooltip: 'Media Actions',
          onTap: () => _showMediaActions(context, ref, displayTrack),
        ),
        ReusableHoverIconButton(
          icon: UIcons.regular.menu_dots_vertical,
          color: Colors.white70,
          tooltip: 'Audio Settings',
          // [DRY PRINCIPLE] Reuses the existing, reusable AudioSettingsSheet
          // to avoid duplicating Speed/Pitch slider code.
          onTap: () => AudioSettingsSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildAudioArtwork() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Hero(
          tag: 'player_artwork_${displayTrack.id ?? displayTrack.hashCode}',
          child: MediaArtworkWidget(item: displayTrack),
        ),
      ),
    );
  }

  SliverPadding _buildAudioMetadataSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 420,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: MetadataCard(track: displayTrack)),
                    const SizedBox(height: 24),
                    const NextInQueueCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(child: MiniLyricsCard(height: 420)),
            ],
          ),
        ),
      ),
    );
  }
}
