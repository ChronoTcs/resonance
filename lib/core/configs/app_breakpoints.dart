import 'package:flutter/widgets.dart';

/// Standardized responsive breakpoint definitions aligned with Material 3 Window Size Classes.
abstract class AppBreakpoints {
  /// Material 3 Compact threshold (Mobile phones in portrait). Viewports < 600dp.
  static const double compact = 600.0;

  /// Material 3 Medium threshold (Tablets, foldables, snapped desktop windows). 600dp <= Viewports < 840dp.
  static const double medium = 840.0;

  /// Material 3 Expanded threshold (Full monitors, wide desktop displays). Viewports >= 1200dp.
  static const double expanded = 1200.0;

  /// Returns `true` if viewport width is less than [compact] (600dp).
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  /// Returns `true` if raw width is less than [compact] (600dp).
  static bool isCompactWidth(double width) => width < compact;

  /// Returns `true` if viewport width is between [compact] (600dp) and [medium] (840dp).
  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compact && w < medium;
  }

  /// Returns `true` if raw width is between [compact] (600dp) and [medium] (840dp).
  static bool isMediumWidth(double width) => width >= compact && width < medium;

  /// Returns `true` if viewport width is >= [compact] (600dp) - Wide desktop / tablet mode.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= compact;

  /// Returns `true` if raw width is >= [compact] (600dp).
  static bool isWideWidth(double width) => width >= compact;

  /// Returns `true` if viewport width is >= [medium] (840dp) - Expanded multi-column mode.
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  /// Returns `true` if raw width is >= [medium] (840dp).
  static bool isExpandedWidth(double width) => width >= medium;
}
