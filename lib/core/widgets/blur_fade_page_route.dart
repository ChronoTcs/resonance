import 'package:flutter/material.dart';

/// [InstantPageRoute] — zero-duration route for use with [BlurTransitionOverlay].
///
/// The overlay provides all visual transition; this route just pushes the page
/// onto the navigator stack with no animation of its own.
///
/// Usage:
/// ```dart
/// BlurTransitionOverlay.start(ref);
/// Navigator.push(context, InstantPageRoute(child: SomePage()));
/// // In SomePage.initState(), after settling:
/// BlurTransitionOverlay.complete(ref);
/// ```
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({required Widget child, super.settings})
      : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => child,
          transitionsBuilder: (_, _, _, child) => child,
        );
}
