import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/common/loading_skeletons.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/recommendation_sidebar_card.dart';
import 'package:resonance/features/dashboard/presentation/widgets/right_sidebar/right_sidebar_providers.dart';
import 'package:resonance/features/home/presentation/providers/home_feed_provider.dart';
import 'package:resonance/features/library/presentation/widgets/media_actions_bottom_sheet.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';

/// Recommendations feed section for the right sidebar with O(1) virtualized list rendering.
/// Adapts gracefully between expanded panel (310px) and collapsed rail (70px).
class RightSidebarRecommendationSection extends ConsumerStatefulWidget {
  const RightSidebarRecommendationSection({super.key});

  @override
  ConsumerState<RightSidebarRecommendationSection> createState() =>
      _RightSidebarRecommendationSectionState();
}

class _RightSidebarRecommendationSectionState
    extends ConsumerState<RightSidebarRecommendationSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(rightSidebarExpandedProvider);
    final theme = Theme.of(context);
    final quickPicksAsync = ref.watch(quickPicksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (Adapts between full title and compact "Recs" title)
        SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: isExpanded
              ? Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Recommendation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.refresh,
                      iconSize: 16,
                      padding: 6,
                      tooltip: 'Refresh Recommendations',
                      onTap: () => ref.refresh(quickPicksProvider),
                    ),
                  ],
                )
              : Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Recs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 2),
                        ReusableHoverIconButton(
                          icon: UIcons.regular.refresh,
                          iconSize: 13,
                          padding: 2,
                          tooltip: 'Refresh Recommendations',
                          onTap: () => ref.refresh(quickPicksProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

        // Virtualized Recommendations List / Skeleton
        Expanded(
          child: quickPicksAsync.when(
            data: (tracks) {
              if (tracks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      isExpanded ? 'No recommendations available' : 'None',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return SilkyListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                itemCount: tracks.length,
                itemExtent: 62.0,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return RecommendationSidebarCard(
                    key: ValueKey(track.id),
                    track: track,
                    onTap: () => ref.read(audioProvider.notifier).playTrack(track),
                    onMoreActions: () => MediaActionsBottomSheet.show(
                      context: context,
                      item: track,
                    ),
                  );
                },
              );
            },
            loading: () => RightSidebarListSkeleton(isExpanded: isExpanded),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  isExpanded ? 'Failed to load recommendations' : 'Error',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
