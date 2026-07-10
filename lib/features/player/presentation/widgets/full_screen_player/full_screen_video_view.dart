import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:resonance/features/player/application/providers/video_player_notifier.dart';

/// [FullScreenVideoView]
/// Bertanggung jawab HANYA untuk layout mode Video:
/// - Video Surface (media_kit_video dengan NoVideoControls)
/// - Esc Instruction Overlay di atas video
class FullScreenVideoView extends ConsumerWidget {
  const FullScreenVideoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoController = ref.watch(videoPlayerProvider.notifier).controller;
    if (videoController == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // Base Layer: Fullscreen Video Surface
        // SOTA V8.0: BoxFit.contain mencegah cropping pada monitor ultra-wide/vertikal
        Positioned.fill(
          child: Video(
            controller: videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),

        // Top Layer: Esc Instruction Hint
        const _EscInstructionOverlay(),
      ],
    );
  }
}

/// Overlay kecil yang memberi tahu user cara keluar dari fullscreen.
/// Dipisahkan menjadi widget sendiri agar bisa dikontrol visibilitasnya
/// secara independen di masa depan.
class _EscInstructionOverlay extends StatelessWidget {
  const _EscInstructionOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To exit full screen, press ',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              _EscKeyBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge kecil bergaya keyboard yang menampilkan tulisan "Esc".
class _EscKeyBadge extends StatelessWidget {
  const _EscKeyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Text(
        'Esc',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
