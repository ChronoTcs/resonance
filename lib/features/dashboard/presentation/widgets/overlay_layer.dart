import 'package:resonance/core/widgets/widgets.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/player/presentation/notifiers/mini_player_view_notifier.dart';
import 'package:resonance/features/player/presentation/widgets/mini_player/floating/floating_window.dart';

class OverlayLayer extends StatelessWidget {
  final Widget child;

  const OverlayLayer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Main Application Navigator (Base Layer)
          Consumer(
            builder: (context, ref, _) {
              final isPopped = ref.watch(miniPlayerPopProvider).isPopped;
              return Offstage(
                offstage: isPopped,
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: isPopped ? 4000 : null,
                  minHeight: 0,
                  maxHeight: isPopped ? 4000 : null,
                  alignment: Alignment.topLeft,
                  child: child,
                ),
              );
            },
          ),

          // Layer 2: Sibling Global Overlay (Top Layer)
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => Consumer(
                    builder: (context, ref, _) {
                      final isPopped = ref.watch(miniPlayerPopProvider).isPopped;
                      return Material(
                        type: MaterialType.transparency,
                        child: Stack(
                          children: [
                            if (isPopped && Platform.isWindows)
                              const FloatingWindow(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Layer 3: Global blur flash
          const BlurTransitionLayer(),
        ],
      ),
    );

    if (Platform.isWindows) {
      return ExcludeSemantics(child: content);
    }
    return content;
  }
}
