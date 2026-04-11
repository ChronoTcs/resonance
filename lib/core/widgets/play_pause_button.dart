import 'package:flutter/material.dart';
import 'reusable_hover_icon_button.dart';

enum PlayPauseSize { small, medium, large }

/// Komponen terpadu untuk tombol Play/Pause dengan integasi Loading Spinner.
/// Menggunakan ReusableHoverIconButton sebagai basis agar hover & tooltip konsisten.
class PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  final PlayPauseSize size;
  final Color? color;
  final Color? iconColor;
  final Color? backgroundColor;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.size = PlayPauseSize.medium,
    this.color,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    double iconSize;
    double padding;
    
    switch (size) {
      case PlayPauseSize.small:
        iconSize = 24.0;
        padding = 8.0;
        break;
      case PlayPauseSize.medium:
        iconSize = 36.0;
        padding = 10.0;
        break;
      case PlayPauseSize.large:
        iconSize = 42.0;
        padding = 14.0;
        break;
    }

    if (isLoading) {
      return SizedBox(
        width: iconSize + (padding * 2),
        height: iconSize + (padding * 2),
        child: Padding(
          padding: EdgeInsets.all(padding + 4),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: color ?? theme.primaryColor,
          ),
        ),
      );
    }

    return ReusableHoverIconButton(
      tooltip: isPlaying ? 'Pause' : 'Play',
      icon: isPlaying 
          ? (size == PlayPauseSize.large ? Icons.pause_rounded : Icons.pause_circle_filled)
          : (size == PlayPauseSize.large ? Icons.play_arrow_rounded : Icons.play_circle_filled),
      iconSize: iconSize,
      padding: padding,
      color: color ?? theme.primaryColor,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
      onTap: onTap,
    );
  }
}
