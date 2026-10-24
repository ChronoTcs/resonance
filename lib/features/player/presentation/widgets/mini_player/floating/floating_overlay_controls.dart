import 'package:resonance/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/application/providers/audio_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';

import 'package:resonance/features/player/data/models/player_enums.dart';

class FloatingOverlayControls extends ConsumerStatefulWidget {
  const FloatingOverlayControls({super.key});

  @override
  ConsumerState<FloatingOverlayControls> createState() => _FloatingOverlayControlsState();
}

class _FloatingOverlayControlsState extends ConsumerState<FloatingOverlayControls> {
  double _lastVolume = 50;

  void _toggleMute(double currentVolume, AudioNotifier notifier) {
    if (currentVolume > 0) {
      setState(() => _lastVolume = currentVolume);
      notifier.setVolume(0);
    } else {
      notifier.setVolume(_lastVolume > 10 ? _lastVolume : 50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverlayVisible = ref.watch(
      miniPlayerPopProvider.select((s) => s.viewState == MiniPlayerViewState.hover),
    );
    if (!isOverlayVisible) {
      return const SizedBox.shrink();
    }

    final (isShuffleEnabled, loopMode, volume, speed, pitch) = ref.watch(
      audioProvider.select((s) => (
        s.isShuffleEnabled,
        s.loopMode,
        s.volume,
        s.speed,
        s.pitch,
      )),
    );
    final audioNotifier = ref.read(audioProvider.notifier);
    final popNotifier = ref.read(miniPlayerPopProvider.notifier);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BARIS 1: Playback Controls (Shuffle, Lyrics, Repeat)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ReusableHoverIconButton(
                        icon: UIcons.regular.shuffle,
                        onTap: audioNotifier.toggleShuffle,
                        tooltip: 'Shuffle',
                        color: isShuffleEnabled ? Theme.of(context).primaryColor : Colors.white,
                      ),
                      const SizedBox(width: 24),
                      ReusableHoverIconButton(
                        icon: UIcons.regular.microphone,
                        onTap: () => popNotifier.setViewState(MiniPlayerViewState.lyrics),
                        tooltip: 'Open Lyrics',
                        color: Colors.white,
                      ),
                      const SizedBox(width: 24),
                      ReusableHoverIconButton(
                        icon: loopMode == LoopMode.one ? UIcons.regular.arrows_repeat_1 : UIcons.regular.arrows_repeat,
                        onTap: audioNotifier.cycleLoopMode,
                        tooltip: 'Repeat Mode',
                        color: loopMode != LoopMode.off ? Theme.of(context).primaryColor : Colors.white,
                        isSelected: false, 
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  // BARIS 2: VOLUME CONTROL (Interactive Mute & Percentage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ReusableHoverIconButton(
                          icon: _getVolumeIcon(volume),
                          onTap: () => _toggleMute(volume, audioNotifier),
                          tooltip: volume > 0 ? 'Mute' : 'Unmute',
                          iconSize: 18,
                          padding: 4,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            ),
                            child: Slider(
                              value: volume,
                              min: 0,
                              max: 100,
                              onChanged: (v) => audioNotifier.setVolume(v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${volume.round()}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // BARIS 3: AUDIO SETTINGS (Speed Tooltip & Pitch Indicator)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _buildSpeedToggle(speed, audioNotifier),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              activeTrackColor: Theme.of(context).primaryColor,
                              inactiveTrackColor: Colors.white10,
                              thumbColor: Theme.of(context).primaryColor,
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            ),
                            child: Slider(
                              value: pitch,
                              min: -12.0,
                              max: 12.0,
                              onChanged: (v) => audioNotifier.setPitch(v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${pitch >= 0 ? '+' : ''}${pitch.toStringAsFixed(1)}',
                            style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(UIcons.regular.settings_sliders, color: Colors.white38, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSpeedToggle(double currentSpeed, AudioNotifier notifier) {
    const speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
    return ReusableHoverIconButton(
      label: '${currentSpeed}x',
      tooltip: 'Playback Speed',
      onTap: () {
        final nextIdx = (speeds.indexOf(currentSpeed) + 1) % speeds.length;
        notifier.setSpeed(speeds[nextIdx]);
      },
      padding: 4,
      color: Colors.white,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) return UIcons.regular.volume_off;
    if (volume < 50) return UIcons.regular.volume_down;
    return UIcons.regular.volume;
  }
}
