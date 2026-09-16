import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/home/presentation/widgets/hover_track_card.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/application/blocked_tracks_provider.dart';

/// Standalone section displaying scanned local music tracks.
class LocalQuickPicksSection extends ConsumerWidget {
  const LocalQuickPicksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(libraryProvider);
    ref.watch(blockedTracksProvider);
    final blockedNotifier = ref.read(blockedTracksProvider.notifier);
    final localAudios = libraryState.allMedia
        .where((m) => m.type == 'audio' && !blockedNotifier.isBlocked(m.id, path: m.path))
        .take(12)
        .toList();

    if (localAudios.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Icon(UIcons.regular.folder, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Local Quick Picks',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: SilkyListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: localAudios.length,
                itemBuilder: (ctx, idx) => HoverTrackCard(track: localAudios[idx]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
