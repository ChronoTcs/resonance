import 'package:flutter/material.dart';

/// [FluentScrollBehavior]
/// Configures global scroll behavior to match Windows Fluent Design:
/// - Uses [ClampingScrollPhysics] (no bounce effect).
/// - Removes overscroll indicator glow effect.
class FluentScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
