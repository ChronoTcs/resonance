import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/widgets/play_pause_button.dart';
import 'package:resonance/core/widgets/reusable_hover_icon_button.dart';
import 'package:resonance/core/widgets/reusable_seek_slider.dart';

class FloatingBottomBar extends ConsumerWidget {
  const FloatingBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final track = ref.watch(currentTrackProvider);

    if (track == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReusableSeekSlider(
            value: audioState.position.inMilliseconds.toDouble(),
            max: audioState.duration.inMilliseconds > 0 
              ? audioState.duration.inMilliseconds.toDouble() 
              : 0.0,
            onChanged: (v) => audioNotifier.seek(Duration(milliseconds: v.toInt())),
            trackHeight: 2,
            height: 4,
            thumbRadius: 0, // Narrow for miniplayer, thumb appears on hover/drag
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                // Song Info (Marquee Title)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 18,
                        child: _MarqueeText(
                          text: track.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        track.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Kontrol Navigasi (Standardized)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReusableHoverIconButton(
                      icon: UIcons.regular.step_backward,
                      onTap: audioNotifier.skipToPrevious,
                      tooltip: 'Previous',
                      iconSize: 18,
                      padding: 4,
                      isDisabled: audioState.currentIndex <= 0,
                    ),
                    const SizedBox(width: 4),
                    PlayPauseButton(
                      isPlaying: audioState.isPlaying,
                      isLoading: audioState.isLoading,
                      onTap: audioNotifier.togglePlayPause,
                      size: PlayPauseSize.small,
                    ),
                    const SizedBox(width: 4),
                    ReusableHoverIconButton(
                      icon: UIcons.regular.step_forward,
                      onTap: audioNotifier.skipToNext,
                      tooltip: 'Next',
                      iconSize: 18,
                      padding: 4,
                      isDisabled: audioState.nextTrack == null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _startScrolling();
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _animationController.duration = Duration(milliseconds: (maxScroll * 40).toInt());

    while (mounted) {
      await _scrollController.animateTo(
        maxScroll,
        duration: _animationController.duration!,
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) break;
      _scrollController.jumpTo(0);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style),
    );
  }
}
