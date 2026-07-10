import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/player/application/services/queue_orchestrator.dart';
import 'package:resonance/core/widgets/media_artwork_widget.dart';
import 'package:resonance/features/home/presentation/providers/home_navigation_provider.dart';

class ArtistSubPage extends ConsumerWidget {
  const ArtistSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artistGroup = ref.watch(groupedArtistsProvider);

    // Sort artist names A to Z
    final sortedArtists = artistGroup.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (sortedArtists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              UIcons.regular.users,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            const Text('No artists found'),
          ],
        ),
      );
    }

    final library = ref.watch(libraryProvider);
    final audioTracks = library.allMedia
        .where((m) => m.type == 'audio')
        .toList();

    return SilkyListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: sortedArtists.length,
      itemBuilder: (context, index) {
        final artist = sortedArtists[index];
        final tracks = artistGroup[artist] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(UIcons.regular.user, size: 14, color: theme.primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    artist,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            ...tracks.map((t) => ListTile(
                  contentPadding: const EdgeInsets.only(left: 12),
                  leading: MediaArtworkWidget(
                    item: t,
                    width: 40,
                    height: 40,
                    borderRadius: 6,
                  ),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    t.artist ?? 'Unknown Artist',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  onTap: () {
                    ref.read(queueOrchestratorProvider).playSequentialContext(t, audioTracks);
                  },
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
