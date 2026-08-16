import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/application/services/network_connectivity_service.dart';
import 'package:resonance/core/utils/uicons.dart';

/// A slim animated banner that slides down when the device is offline
/// and auto-dismisses 2 seconds after reconnecting. Designed for use
/// inside a Column above scrollable content.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _heightFactor;
  Timer? _dismissTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _heightFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _show() {
    _dismissTimer?.cancel();
    if (!_visible) {
      setState(() => _visible = true);
      _ctrl.forward();
    }
  }

  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      _ctrl.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(
      networkConnectivityProvider.select((s) => s.isOnline),
    );

    // React to connectivity changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!isOnline) {
        _show();
      } else if (_visible) {
        _scheduleDismiss();
      }
    });

    if (!_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizeTransition(
      sizeFactor: _heightFactor,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: colors.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(
              UIcons.regular.wifi_slash,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOnline
                    ? 'Back online'
                    : 'You\'re offline — showing local content',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
