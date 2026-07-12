import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/formatters.dart';
import 'package:resonance/core/widgets/blur_fade_page_route.dart';
import 'package:resonance/core/widgets/blur_transition_overlay.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/features/library/data/models/media_item.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';
import 'package:resonance/features/player/presentation/screens/full_screen_player.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/shared/volume_popup_dialog.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/shared/audio_settings_sheet.dart';
import 'package:resonance/features/player/utils/media_action_utils.dart';

import 'package:resonance/core/utils/uicons.dart';

class AudioExtraActions extends ConsumerWidget {
  final MediaItem track;
  final bool isDesktop;

  const AudioExtraActions({
    super.key,
    required this.track,
    this.isDesktop = false,
  });

// Media Action Utils removed, now handled by external utility class.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktop) {
      return ReusableHoverIconButton(
        icon: UIcons.regular.add,
        iconSize: 20,
        tooltip: 'Media actions',
        onTap: () => MediaActionUtils.showMediaActions(
          context: context,
          ref: ref,
          item: track,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ReusableHoverIconButton(
            icon: UIcons.regular.add,
            iconSize: 20,
            tooltip: 'Media actions',
            onTap: () => MediaActionUtils.showMediaActions(
              context: context,
              ref: ref,
              item: track,
            ),
          ),
          const SizedBox(width: 8),
          Consumer(
            builder: (context, ref, _) {
              final pos = ref.watch(audioProvider.select((s) => s.position));
              final dur = ref.watch(audioProvider.select((s) => s.duration));
              return SizedBox(
                width: 110, // Fixed width to prevent jitter
                child: Text(
                  "${AppFormatters.formatDuration(pos)} / ${AppFormatters.formatDuration(dur)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (buttonContext) {
              final v = ref.watch(audioProvider.select((s) => s.volume));
              return ReusableHoverIconButton(
                tooltip: 'Volume',
                icon: v == 0
                    ? UIcons.regular.volume_off
                    : v < 50
                        ? UIcons.regular.volume_down
                        : UIcons.regular.volume,
                onTap: () {
                  final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
                  final offset = renderBox.localToGlobal(Offset.zero);
                  final buttonSize = renderBox.size;
                  
                  VolumePopupDialog.show(
                    context: context,
                    buttonOffset: offset,
                    buttonSize: buttonSize,
                  );
                },
              );
            },
          ),
          ReusableHoverIconButton(
            icon: UIcons.regular.settings,
            tooltip: 'Settings',
            onTap: () => AudioSettingsSheet.show(context),
          ),
          if (Platform.isWindows)
            Consumer(
              builder: (context, ref, _) {
                final isPopped = ref.watch(miniPlayerPopProvider.select((s) => s.isPopped));
                return ReusableHoverIconButton(
                  icon: isPopped ? UIcons.regular.window_restore : UIcons.regular.window_alt,
                  tooltip: isPopped ? 'Close Miniplayer' : 'Open Miniplayer',
                  onTap: () => BlurTransitionOverlay.run(
                    ref,
                    () async => ref.read(miniPlayerPopProvider.notifier).togglePop(),
                  ),
                  iconSize: 20,
                );
              },
            ),
          ReusableHoverIconButton(
            icon: UIcons.regular.expand,
            tooltip: 'Full Screen',
            onTap: () {
              // Close PiP before fullscreen to prevent visual overlap
              final isPopped = ref.read(miniPlayerPopProvider).isPopped;
              if (isPopped) {
                ref.read(miniPlayerPopProvider.notifier).togglePop();
              }
              // Blur appears immediately; FullScreenPlayer.initState() calls complete()
              BlurTransitionOverlay.start(ref);
              Navigator.of(context, rootNavigator: true).push(
                InstantPageRoute(
                  settings: const RouteSettings(name: '/fullscreen_player'),
                  child: const FullScreenPlayer(),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
