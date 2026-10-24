import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';

/// Unified reusable hover play button for music artwork cards (e.g., Recommended for You, Speed Dial).
///
/// Features an icon-only hover aesthetic with ZERO background boxes or outer circles:
/// - Smooth [AnimatedScale] (1.0 resting -> 1.18 hovered with [Curves.easeOutBack]).
/// - Dynamic icon glow and depth shadows.
/// - Integrated loading spinner and play/pause state synchronization.
/// - Native desktop tooltip feedback.
class CardHoverPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  final double iconSize;
  final Color? color;
  final String? tooltip;

  const CardHoverPlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.iconSize = 36.0,
    this.color,
    this.tooltip,
  });

  @override
  State<CardHoverPlayButton> createState() => _CardHoverPlayButtonState();
}

class _CardHoverPlayButtonState extends State<CardHoverPlayButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final effectiveColor = widget.color ?? Colors.white;

    if (widget.isLoading) {
      return SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: widget.color ?? primary,
          ),
        ),
      );
    }

    final iconWidget = Icon(
      widget.isPlaying ? UIcons.regular.pause : UIcons.regular.play,
      size: widget.iconSize,
      color: _isHovered ? effectiveColor : effectiveColor.withValues(alpha: 0.88),
      shadows: const [
        Shadow(
          color: Color(0x80000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );

    Widget content = Transform.scale(
      scale: _isHovered ? 1.15 : 1.0,
      child: iconWidget,
    );

    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        verticalOffset: (widget.iconSize / 2) + 14,
        child: content,
      );
    }

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (event) {
          if (event.kind == PointerDeviceKind.touch) return;
          if (!_isHovered) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          if (_isHovered) {
            setState(() => _isHovered = false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: content,
        ),
      ),
    );
  }
}
