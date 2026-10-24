import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../../../player/application/providers/audio_provider.dart';

/// Compact lyrics offset adjustment control with hold-to-accelerate.
/// - Single tap: ±0.5s step
/// - Press & hold: smooth 3-tier acceleration for rapid multi-second offsets
/// - Tap center badge: instantly resets offset to 0.0s
class LyricsOffsetControl extends ConsumerWidget {
  /// Visual scale: use [compact] for tight spaces like the mini lyrics card header.
  final bool compact;
  const LyricsOffsetControl({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offsetMs = ref.watch(
      audioProvider.select((s) => s.currentTrack?.lyricsOffset.inMilliseconds ?? 0),
    );
    final notifier = ref.read(audioProvider.notifier);
    final iconSize = compact ? 15.0 : 18.0;
    final fontSize = compact ? 11.0 : 12.0;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HoldAccelerateButton(
            icon: UIcons.regular.minus,
            iconSize: iconSize,
            padding: compact ? 2.0 : 3.0,
            color: color.withValues(alpha: 0.85),
            tooltip: 'Delay lyrics (Hold to accelerate)',
            onTick: (deltaMs) => notifier.adjustLyricsOffset(Duration(milliseconds: -deltaMs)),
          ),
          const SizedBox(width: 3),
          Tooltip(
            message: offsetMs != 0 ? 'Click to reset offset' : 'Lyrics sync offset',
            child: MouseRegion(
              cursor: offsetMs != 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (offsetMs != 0) {
                    notifier.adjustLyricsOffset(Duration(milliseconds: -offsetMs));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: offsetMs != 0
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: Text(
                    '${(offsetMs / 1000).toStringAsFixed(1)}s',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: offsetMs != 0 ? theme.colorScheme.primary : color.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          _HoldAccelerateButton(
            icon: UIcons.regular.plus,
            iconSize: iconSize,
            padding: compact ? 2.0 : 3.0,
            color: color.withValues(alpha: 0.85),
            tooltip: 'Advance lyrics (Hold to accelerate)',
            onTick: (deltaMs) => notifier.adjustLyricsOffset(Duration(milliseconds: deltaMs)),
          ),
        ],
      ),
    );
  }
}

class _HoldAccelerateButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final double padding;
  final Color color;
  final String tooltip;
  final void Function(int deltaMs) onTick;

  const _HoldAccelerateButton({
    required this.icon,
    required this.iconSize,
    required this.padding,
    required this.color,
    required this.tooltip,
    required this.onTick,
  });

  @override
  State<_HoldAccelerateButton> createState() => _HoldAccelerateButtonState();
}

class _HoldAccelerateButtonState extends State<_HoldAccelerateButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  Timer? _initialDelayTimer;
  Timer? _repeatTimer;
  int _repeatTicks = 0;

  void _startHold() {
    if (_isPressed) return;
    _isPressed = true;
    _repeatTicks = 0;
    setState(() {});

    // 1. Immediate trigger on initial press (500ms)
    widget.onTick(500);

    // 2. Debounce threshold before continuous acceleration engages
    _initialDelayTimer?.cancel();
    _initialDelayTimer = Timer(const Duration(milliseconds: 350), () {
      if (!_isPressed) return;
      _repeatTimer?.cancel();
      // Tick every 100ms
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!_isPressed) {
          _stopHold();
          return;
        }
        _repeatTicks++;
        // Acceleration calculation:
        // - First 12 ticks (~1.2s): 500ms per tick
        // - Next 13 ticks (1.2s - 2.5s): 1000ms per tick
        // - > 25 ticks (> 2.5s): 2000ms per tick
        final int deltaMs;
        if (_repeatTicks <= 12) {
          deltaMs = 500;
        } else if (_repeatTicks <= 25) {
          deltaMs = 1000;
        } else {
          deltaMs = 2000;
        }
        widget.onTick(deltaMs);
      });
    });
  }

  void _stopHold() {
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatTicks = 0;
    if (_isPressed) {
      _isPressed = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _initialDelayTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.touch) return;
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
        if (_isPressed) _stopHold();
      },
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        verticalOffset: 24,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _startHold(),
            onPointerUp: (_) => _stopHold(),
            onPointerCancel: (_) => _stopHold(),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _isPressed ? 0.92 : (_isHovered ? 1.15 : 1.0),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.all(widget.padding),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _isHovered
                      ? widget.color.withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
