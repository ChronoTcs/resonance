import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of the left navigation sidebar: expanded (180px) or shrunk (50px rail).
/// Defaults to false (collapsed) for clean minimal desktop window sizes.
class LeftSidebarExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void setExpanded(bool value) => state = value;
}

final leftSidebarExpandedProvider =
    NotifierProvider<LeftSidebarExpandedNotifier, bool>(LeftSidebarExpandedNotifier.new);
