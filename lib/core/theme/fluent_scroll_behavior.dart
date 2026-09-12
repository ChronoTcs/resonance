import 'dart:io';
import 'package:flutter/material.dart';

/// [FluentScrollBehavior]
/// Configures scroll behavior adaptively:
/// - Windows / Desktop: ClampingScrollPhysics with silent indicator.
/// - Android / Mobile: BouncingScrollPhysics with StretchingOverscrollIndicator for natural touch feedback.
class FluentScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (Platform.isAndroid) {
      return StretchingOverscrollIndicator(
        axisDirection: details.direction,
        child: child,
      );
    }
    return child;
  }
}

