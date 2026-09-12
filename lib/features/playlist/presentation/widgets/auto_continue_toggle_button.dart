import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/buttons/reusable_hover_icon_button.dart';
import 'package:resonance/features/playlist/application/playlist_auto_continue_provider.dart';

/// Reusable toggle button for Playlist Auto Continue.
/// When OFF: shows infinity icon with a diagonal slash across it.
/// When ON: slash is removed and icon switches to vibrant accent color with tinted pill.
class AutoContinueToggleButton extends ConsumerWidget {
  final String playlistId;
  final double iconSize;
  final double padding;

  const AutoContinueToggleButton({
    super.key,
    required this.playlistId,
    this.iconSize = 20.0,
    this.padding = 6.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAutoContinue =
        ref.watch(playlistAutoContinueProvider).contains(playlistId);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ReusableHoverIconButton(
      tooltip: isAutoContinue
          ? 'Auto Continue: ON (recommends tracks when playlist ends)'
          : 'Auto Continue: OFF (stops at end of playlist)',
      padding: padding,
      backgroundColor: isAutoContinue
          ? primary.withValues(alpha: 0.14)
          : Colors.transparent,
      hoverColor: primary,
      onTap: () =>
          ref.read(playlistAutoContinueProvider.notifier).toggle(playlistId),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            UIcons.regular.infinity,
            size: iconSize,
            color: isAutoContinue
                ? primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          if (!isAutoContinue) ...[
            // Cutout background for clean visual separation
            Transform.rotate(
              angle: -0.75,
              child: Container(
                width: iconSize * 1.05,
                height: 3.2,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Foreground slash line
            Transform.rotate(
              angle: -0.75,
              child: Container(
                width: iconSize * 1.05,
                height: 1.6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
