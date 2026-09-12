import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

/// Floating Banner Overlay for immediate visual notification feedback.
/// Supports responsive safe-area offset on mobile and top-right positioning on desktop.
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
    setState(() => _activeBanner = item);
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _activeBanner = null);
    });
  }

  void _dismissBanner() {
    setState(() => _activeBanner = null);
  }

  void _handleBannerTap(String? targetScreen) {
    if (targetScreen == null) return;
    ref.read(notificationProvider.notifier).markAllAsRead();
    ref.read(notificationProvider.notifier).handleNotificationClick(targetScreen: targetScreen);
    _dismissBanner();
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

    final isWide = AppBreakpoints.isWide(context);
    final topSafe = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: isWide ? 16 : (topSafe > 0 ? topSafe + 10 : 16),
      right: 16,
      left: isWide ? null : 16,
      child: Align(
        alignment: isWide ? Alignment.topRight : Alignment.topCenter,
        child: _BannerCard(
          banner: banner,
          isWide: isWide,
          onTap: banner.targetScreen != null ? () => _handleBannerTap(banner.targetScreen) : null,
          onDismiss: _dismissBanner,
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final NotificationItem banner;
  final bool isWide;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _BannerCard({
    required this.banner,
    required this.isWide,
    this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = banner.isError
        ? theme.colorScheme.error.withValues(alpha: 0.5)
        : theme.colorScheme.primary.withValues(alpha: 0.3);

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        mouseCursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isWide
                ? (MediaQuery.sizeOf(context).width - 32.0).clamp(240.0, 320.0)
                : 420.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BannerTextContent(banner: banner),
              ),
              if (banner.actionLabel != null && banner.onAction != null) ...[
                const SizedBox(width: 8),
                _BannerActionButton(
                  label: banner.actionLabel!,
                  onPressed: () {
                    onDismiss();
                    banner.onAction?.call();
                  },
                ),
              ],
              ReusableHoverIconButton(
                icon: UIcons.regular.cross_small,
                tooltip: 'Dismiss',
                iconSize: 13.0,
                padding: 4.0,
                onTap: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerTextContent extends StatelessWidget {
  final NotificationItem banner;

  const _BannerTextContent({required this.banner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BannerActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: theme.colorScheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      child: Text(label),
    );
  }
}
