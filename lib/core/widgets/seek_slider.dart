import 'package:flutter/material.dart';

class SeekSlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;

  const SeekSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<SeekSlider> {
  double? _hoverValue;
  bool _isHovering = false;
  bool _isDragging = false;
  double _dragValue = 0;

  // The Slider widget has internal horizontal padding matching the overlay radius.
  // We set overlayRadius to 14 in SliderTheme, so we use that here for alignment.
  static const double horizontalPadding = 14.0;

  String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.primaryColor;
    final inactiveColor = widget.inactiveColor ?? theme.colorScheme.onSurface.withOpacity(0.1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = totalWidth - (2 * horizontalPadding);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          onHover: (event) {
            setState(() {
              // Map local X to the track area (14.0 to totalWidth - 14.0)
              final double localX = event.localPosition.dx;
              final double normalizedX = (localX - horizontalPadding) / trackWidth;
              _hoverValue = (normalizedX * widget.max).clamp(0.0, widget.max);
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: horizontalPadding),
                  activeTrackColor: activeColor,
                  inactiveTrackColor: inactiveColor,
                  thumbColor: activeColor,
                ),
                child: Slider(
                  value: widget.value.clamp(0.0, widget.max),
                  max: widget.max > 0 ? widget.max : 1.0,
                  onChanged: (val) {
                    setState(() => _dragValue = val);
                    widget.onChanged(val);
                  },
                  onChangeStart: (val) {
                    setState(() {
                      _isDragging = true;
                      _dragValue = val;
                    });
                    widget.onChangeStart?.call(val);
                  },
                  onChangeEnd: (val) {
                    setState(() => _isDragging = false);
                    widget.onChangeEnd?.call(val);
                  },
                ),
              ),
              if ((_isHovering || _isDragging) && widget.max > 0)
                Positioned(
                  left: _calculateTooltipX(totalWidth, trackWidth),
                  top: -35,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _formatDuration(Duration(seconds: (_isDragging ? _dragValue : (_hoverValue ?? 0)).toInt())),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        // Triangle pointer
                        CustomPaint(
                          size: const Size(10, 5),
                          painter: _TooltipPointerPainter(
                            color: theme.colorScheme.secondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _calculateTooltipX(double totalWidth, double trackWidth) {
    double progress;
    if (_isDragging) {
      progress = _dragValue / (widget.max > 0 ? widget.max : 1.0);
    } else if (_hoverValue != null) {
      progress = _hoverValue! / (widget.max > 0 ? widget.max : 1.0);
    } else {
      return 0;
    }
    
    // Position tooltip relative to the track start + progress * trackWidth
    return (horizontalPadding + (progress * trackWidth)).clamp(0.0, totalWidth);
  }
}

class _TooltipPointerPainter extends CustomPainter {
  final Color color;

  _TooltipPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
