import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/features/player/application/providers/video_player_notifier.dart' as v;

class VolumePopupDialog extends ConsumerWidget {
  final Offset buttonOffset;
  final Size buttonSize;
  final bool isVideo;

  const VolumePopupDialog({
    super.key,
    required this.buttonOffset,
    required this.buttonSize,
    required this.isVideo,
  });

  static void show({
    required BuildContext context,
    required Offset buttonOffset,
    required Size buttonSize,
    required bool isVideo,
  }) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => VolumePopupDialog(
        buttonOffset: buttonOffset,
        buttonSize: buttonSize,
        isVideo: isVideo,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const double dialogWidth = 300;
    const double dialogHeight = 64;

    double left = buttonOffset.dx - (dialogWidth / 2) + (buttonSize.width / 2);
    final screenWidth = MediaQuery.of(context).size.width;
    if (left < 16) left = 16;
    if (left + dialogWidth > screenWidth - 16) {
      left = screenWidth - dialogWidth - 16;
    }

    double top = buttonOffset.dy - dialogHeight - 16;

    // Menarik value sesuai domain yang memanggilnya
    final double currentVolume = isVideo
        ? ref.watch(v.videoPlayerProvider.select((s) => s.volume))
        : ref.watch(audioProvider.select((s) => s.volume));

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: dialogWidth,
                  height: dialogHeight,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Icon(
                          currentVolume == 0
                              ? UIcons.regular.volume_off
                              : currentVolume < (isVideo ? 0.5 : 50)
                                  ? UIcons.regular.volume_down
                                  : UIcons.regular.volume,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: theme.primaryColor,
                              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                              thumbColor: theme.primaryColor,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 4,
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: currentVolume,
                              min: 0.0,
                              max: isVideo ? 1.0 : 100.0,
                              onChanged: (val) {
                                if (isVideo) {
                                  ref.read(v.videoPlayerProvider.notifier).setVolume(val);
                                } else {
                                  ref.read(audioProvider.notifier).setVolume(val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 44,
                          child: Text(
                            isVideo
                                ? "${(currentVolume * 100).toInt()}%"
                                : "${currentVolume.toInt()}%",
                            softWrap: false,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.right,
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
      ],
    );
  }
}
