import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/utils/uicons.dart';
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
          onTap: () {
            ref.read(notificationProvider.notifier).markAllAsRead();
            ref.read(notificationProvider.notifier).handleNotificationClick(targetScreen: banner.targetScreen);
            setState(() {
              _activeBanner = null;
            });
          },
          child: Container(
            width: 320,
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
                Icon(
                  banner.isError ? UIcons.regular.exclamation : UIcons.regular.download,
                  size: 20,
                  color: banner.isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        banner.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
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
