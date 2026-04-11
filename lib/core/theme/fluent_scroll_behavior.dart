import 'package:flutter/material.dart';

/// [FluentScrollBehavior]
/// Mengatur perilaku scroll global agar menyerupai Fluent Design (Windows):
/// - Menggunakan [ClampingScrollPhysics] (tanpa efek bounce).
/// - Menghilangkan indikator overscroll (efek cahaya saat mentok).
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
