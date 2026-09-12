import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

/// Top-Right Floating Banner Overlay for immediate visual notification feedback.
class NotificationBannerOverlay extends ConsumerStatefulWidget {
  const NotificationBannerOverlay({super.key});

  @override
  ConsumerState<NotificationBannerOverlay> createState() => _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState extends ConsumerState<NotificationBannerOverlay> {
  NotificationItem? _activeBanner;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _showBanner(NotificationItem item) {
    _dismissTimer?.cancel();
    setState(() {
      _activeBanner = item;
    });
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _activeBanner = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationProvider, (previous, current) {
      if (current.items.isNotEmpty) {
        final newest = current.items.first;
        if (previous == null || previous.items.isEmpty || previous.items.first.id != newest.id) {
          _showBanner(newest);
        }
      }
    });

    final banner = _activeBanner;
    if (banner == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          mouseCursor: banner.targetScreen != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: banner.targetScreen != null
              ? () {
                  ref.read(notificationProvider.notifier).markAllAsRead();
                  ref
                      .read(notificationProvider.notifier)
                      .handleNotificationClick(targetScreen: banner.targetScreen);
                  setState(() {
                    _activeBanner = null;
                  });
                }
              : null,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (MediaQuery.sizeOf(context).width - 32.0).clamp(240.0, 320.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: banner.isError
                    ? theme.colorScheme.error.withValues(alpha: 0.5)
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              banner.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (banner.targetScreen != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              UIcons.regular.angle_small_right,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banner.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (banner.actionLabel != null && banner.onAction != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final action = banner.onAction;
                      setState(() {
                        _activeBanner = null;
                      });
                      action?.call();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: theme.colorScheme.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    child: Text(banner.actionLabel!),
                  ),
                ],
                ReusableHoverIconButton(
                  icon: UIcons.regular.cross_small,
                  tooltip: 'Dismiss',
                  iconSize: 13.0,
                  padding: 4.0,
                  onTap: () {
                    setState(() {
                      _activeBanner = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
