import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

/// Self-contained notification bell icon + dropdown overlay.
/// Lives in the dashboard feature — legal to read notificationProvider here.
class NotificationBell extends ConsumerStatefulWidget {
  final Color? iconColor;
  final bool isTitleBar;

  const NotificationBell({
    super.key,
    this.iconColor,
    this.isTitleBar = false,
  });

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(BuildContext context, NotificationState notifState) {
    _hideOverlay();
    final theme = Theme.of(context);
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => ref.read(notificationProvider.notifier).toggleDropdown(visible: false),
              behavior: HitTestBehavior.translucent,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            Positioned(
              width: 320,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: widget.isTitleBar ? const Offset(-280, 32) : const Offset(-270, 40),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: theme.colorScheme.surface.withValues(alpha: 0.95),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Notifications',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (notifState.items.isNotEmpty)
                                ResonanceButton(
                                  onPressed: () {
                                    ref.read(notificationProvider.notifier).clearAll();
                                    ref.read(notificationProvider.notifier).toggleDropdown(visible: false);
                                  },
                                  icon: UIcons.regular.trash,
                                  label: 'Clear All',
                                  style: ResonanceButtonStyle.secondary,
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: notifState.items.isEmpty
                              ? SizedBox(
                                  height: 52,
                                  child: Center(
                                    child: Text(
                                      'No new notifications',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: notifState.items.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = notifState.items[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        item.isError
                                            ? UIcons.regular.exclamation
                                            : UIcons.regular.check,
                                        color: item.isError
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.primary,
                                        size: 16,
                                      ),
                                      title: Text(
                                        item.title,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: item.isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        item.message,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      onTap: () {
                                        ref.read(notificationProvider.notifier).markAllAsRead();
                                        ref.read(notificationProvider.notifier).toggleDropdown(visible: false);
                                        ref.read(notificationProvider.notifier).handleNotificationClick(targetScreen: item.targetScreen);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationProvider);
    final unreadCount = notifState.items.where((i) => !i.isRead).length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (notifState.isDropdownVisible) {
        _hideOverlay();
        _showOverlay(context, notifState);
      } else {
        _hideOverlay();
      }
    });

    if (widget.isTitleBar) {
      return CompositedTransformTarget(
        link: _layerLink,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _TitleBarBellIconButton(
              iconColor: widget.iconColor ?? Colors.white,
              onTap: () => ref.read(notificationProvider.notifier).toggleDropdown(),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ReusableHoverIconButton(
            icon: UIcons.regular.bell,
            tooltip: 'Notifications',
            iconSize: 18,
            color: widget.iconColor,
            onTap: () => ref.read(notificationProvider.notifier).toggleDropdown(),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleBarBellIconButton extends StatefulWidget {
  final Color iconColor;
  final VoidCallback onTap;

  const _TitleBarBellIconButton({
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_TitleBarBellIconButton> createState() => _TitleBarBellIconButtonState();
}

class _TitleBarBellIconButtonState extends State<_TitleBarBellIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDarkText = widget.iconColor.computeLuminance() > 0.5;
    final hoverBgColor = isDarkText
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    final hoverFgColor = isDarkText ? Colors.white : Colors.black;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Notifications',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            color: _isHovered ? hoverBgColor : Colors.transparent,
            child: Icon(
              UIcons.regular.bell,
              size: 13,
              color: _isHovered ? hoverFgColor : widget.iconColor.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
