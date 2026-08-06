import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/theme/theme_provider.dart';
import 'package:resonance/features/dashboard/presentation/widgets/notification_bell.dart';
import 'package:resonance/features/settings/application/app_behavior_provider.dart';
import 'package:resonance/features/tray/application/tray_service.dart';
class CustomTitleBar extends ConsumerStatefulWidget {
  final String? nowPlayingTitle;
  const CustomTitleBar({super.key, this.nowPlayingTitle});

  @override
  ConsumerState<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends ConsumerState<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isMaximizeHovered = false;

  static const _hoverChannel = MethodChannel('resonance/titlebar_hover');



  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximizedState();
    _hoverChannel.setMethodCallHandler((call) async {
      if (call.method == 'setHovered') {
        if (mounted) {
          setState(() {
            _isMaximizeHovered = call.arguments as bool;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }


  Future<void> _checkMaximizedState() async {
    final max = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = max);
    }
  }

  void _toggleTheme() {
    final current = ref.read(themeProvider);
    final modes = AppThemeMode.values;
    final next = modes[(current.index + 1) % modes.length];
    ref.read(themeProvider.notifier).setTheme(next);
  }

  void _toggleAccent() {
    final current = ref.read(accentColorProvider);
    final accentModes = [
      null,
      'windows',
      'palette1',
      'palette2',
      'palette3',
      'palette4',
      'palette5',
      'palette6',
      'palette7',
      'palette8',
    ];
    final idx = accentModes.indexOf(current);
    final next = accentModes[(idx + 1) % accentModes.length];
    ref.read(accentColorProvider.notifier).setAccentColor(next);
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return UIcons.regular.laptop;
      case AppThemeMode.light:
        return UIcons.regular.sun;
      case AppThemeMode.dark:
        return UIcons.regular.moon;
      case AppThemeMode.onyx:
        return UIcons.regular.eclipse;
    }
  }

  String _getThemeTooltip(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Theme: System Default';
      case AppThemeMode.light:
        return 'Theme: Gilded Ivory (Light)';
      case AppThemeMode.dark:
        return 'Theme: Deep Opulence (Dark)';
      case AppThemeMode.onyx:
        return 'Theme: Onyx (Pure Dark)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final accentMode = ref.watch(accentColorProvider);

    final titleText = widget.nowPlayingTitle != null
        ? '${widget.nowPlayingTitle} | Resonance'
        : 'Resonance';

    // Resolve palette/accent gradient colors dynamically from the ColorScheme
    final primaryColor = theme.colorScheme.primary;
    final tertiaryColor = theme.colorScheme.tertiary;
    final gradientColors = [primaryColor, tertiaryColor];

    // Determine text & icon colors (contrast)
    final double luminance = gradientColors.first.computeLuminance();
    final Color contentColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Left side: Native-styled App Icon & Title Drag Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/app_icon.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titleText,
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: contentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right side: Custom Toggles & Windows 11 styled Controls
          Row(
            children: [
              // Notification Bell (UIcons.regular.bell)
              NotificationBell(
                isTitleBar: true,
                iconColor: contentColor,
              ),
              // Accent Color Cycle
              _TitleBarCompactButton(
                icon: UIcons.regular.paint_brush,
                tooltip: accentMode == null
                    ? 'Accent: Default'
                    : accentMode == 'windows'
                        ? 'Accent: Windows Theme'
                        : 'Accent: Palette ${accentMode.replaceAll("palette", "")}',
                onTap: _toggleAccent,
                contentColor: contentColor,
              ),
              // Theme Cycle
              _TitleBarCompactButton(
                icon: _getThemeIcon(themeMode),
                tooltip: _getThemeTooltip(themeMode),
                onTap: _toggleTheme,
                contentColor: contentColor,
              ),
              const SizedBox(width: 8),

              // Windows 11 Native Control Button Mockups
              _WindowControlButton(
                tooltip: 'Minimize',
                onTap: windowManager.minimize,
                contentColor: contentColor,
                child: Container(
                  width: 10,
                  height: 1.0,
                  color: contentColor,
                ),
              ),
              _WindowControlButton(
                tooltip: _isMaximized ? 'Restore Down' : 'Maximize',
                showTooltip: false, // Disable Flutter tooltip so native Windows 11 Snap Layouts hover handles it
                isHoveredOverride: _isMaximizeHovered,
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                contentColor: contentColor,
                child: Icon(
                  _isMaximized ? UIcons.regular.copy : UIcons.regular.square,
                  size: 11,
                  color: contentColor,
                ),
              ),
              _WindowControlButton(
                tooltip: 'Close',
                onTap: () {
                  final closeToTray = ref.read(appBehaviorProvider).closeToTray;
                  if (closeToTray) {
                    windowManager.hide();
                  } else {
                    ref.read(trayServiceProvider).handleExit();
                  }
                },
                contentColor: contentColor,
                isClose: true,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBarCompactButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color contentColor;

  const _TitleBarCompactButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.contentColor,
  });

  @override
  State<_TitleBarCompactButton> createState() => _TitleBarCompactButtonState();
}

class _TitleBarCompactButtonState extends State<_TitleBarCompactButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isLight = widget.contentColor.computeLuminance() > 0.5;
    final hoverBgColor = isLight
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    final hoverFgColor = isLight ? Colors.white : Colors.black;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            color: _isHovered ? hoverBgColor : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 13,
              color: _isHovered ? hoverFgColor : widget.contentColor.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Color contentColor;
  final Widget child;
  final bool isClose;
  final bool showTooltip;
  final bool? isHoveredOverride;

  const _WindowControlButton({
    required this.tooltip,
    required this.onTap,
    required this.contentColor,
    required this.child,
    this.isClose = false,
    this.showTooltip = true,
    this.isHoveredOverride,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeHovered = widget.isHoveredOverride ?? _isHovered;

    final hoverBgColor = widget.isClose
        ? const Color(0xFFE81123)
        : Colors.white.withValues(alpha: 0.12);

    final resolvedColor = widget.isClose && activeHovered
        ? Colors.white
        : widget.contentColor;

    Widget buttonContent = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 46,
        height: 32,
        color: activeHovered ? hoverBgColor : Colors.transparent,
        child: Center(
          child: Theme(
            data: ThemeData(
              iconTheme: IconThemeData(color: resolvedColor),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.showTooltip
          ? Tooltip(
              message: widget.tooltip,
              child: buttonContent,
            )
          : buttonContent,
    );
  }
}
