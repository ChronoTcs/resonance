import 'package:flutter/material.dart';
import 'package:resonance/core/utils/uicons.dart';
import '../buttons/reusable_hover_icon_button.dart';

/// Reusable subview layout with a pinned sticky top header (back button + title)
/// and an independently scrollable content area underneath.
class StickySubViewLayout extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsetsGeometry contentPadding;
  final ScrollPhysics physics;

  const StickySubViewLayout({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
    this.trailing,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
    this.physics = const ClampingScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Sticky Top Header ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              ReusableHoverIconButton(
                icon: UIcons.regular.angle_small_left,
                tooltip: 'Back',
                onTap: onBack,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
        ),

        // ── Scrollable Body Content ─────────────────────────────────────────
        Expanded(
          child: ListView(
            physics: physics,
            padding: contentPadding,
            children: children,
          ),
        ),
      ],
    );
  }
}
