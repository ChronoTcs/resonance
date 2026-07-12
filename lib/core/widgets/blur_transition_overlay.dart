import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _blurTransitionProvider = NotifierProvider<_BlurNotifier, bool>(
  _BlurNotifier.new,
);

class _BlurNotifier extends Notifier<bool> {
  @override
  bool build() {
    BlurTransitionOverlay._notifier = this;
    return false;
  }

  void show() => state = true;
  void hide() => state = false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Controls the full-screen blur overlay.
///
/// **Navigation transitions** (fullscreen push/pop) — manual lifecycle:
/// ```dart
/// // Push side (caller):
/// BlurTransitionOverlay.start(ref);
/// Navigator.push(context, instantRoute);
/// // Destination initState (after window settled):
/// BlurTransitionOverlay.complete(ref);
///
/// // On pop:
/// await BlurTransitionOverlay.startAndWait(ref);
/// await _exitFullScreen();
/// Navigator.pop(context);
/// await Future.delayed(Duration(milliseconds: 100));
/// BlurTransitionOverlay.complete(ref);
/// ```
///
/// **State-change transitions** (mini player toggle) — fire-and-forget:
/// ```dart
/// BlurTransitionOverlay.run(ref, () async => togglePop());
/// ```
class BlurTransitionOverlay {
  /// Time to let AnimatedSwitcher reach full opacity before acting.
  static const _peakDuration = Duration(milliseconds: 260);

  /// Static reference to the notifier, allowing safe execution even if
  /// the triggering widget is unmounted during transitions.
  static _BlurNotifier? _notifier;

  /// Show blur immediately (non-blocking).
  static void start(WidgetRef ref) {
    if (ref.context.mounted) {
      ref.read(_blurTransitionProvider.notifier).show();
    } else {
      _notifier?.show();
    }
  }

  /// Show blur and wait until it is fully visible.
  static Future<void> startAndWait(WidgetRef ref) async {
    if (ref.context.mounted) {
      ref.read(_blurTransitionProvider.notifier).show();
    } else {
      _notifier?.show();
    }
    await Future.delayed(_peakDuration);
  }

  /// Begin fading the blur out.
  static void complete(WidgetRef ref) {
    if (ref.context.mounted) {
      ref.read(_blurTransitionProvider.notifier).hide();
    } else {
      _notifier?.hide();
    }
  }

  /// Blur in → [action] → blur out. For non-navigation state changes.
  static Future<void> run(
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    await startAndWait(ref);
    await action();
    await Future.delayed(const Duration(milliseconds: 80));
    complete(ref);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget — place once in root Stack in main.dart, above all other layers
// ─────────────────────────────────────────────────────────────────────────────

class BlurTransitionLayer extends ConsumerWidget {
  const BlurTransitionLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(_blurTransitionProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: visible
          ? BackdropFilter(
              key: const ValueKey('blur_on'),
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            )
          : const SizedBox.shrink(key: ValueKey('blur_off')),
    );
  }
}
