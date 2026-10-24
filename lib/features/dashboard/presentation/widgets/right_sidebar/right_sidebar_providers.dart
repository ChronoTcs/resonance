import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of the right companion sidebar: expanded (310px) or shrunk (50px rail).
/// Defaults to false (shrunk) so minimal window sizes start clean and uncluttered.
class RightSidebarExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setExpanded(bool val) => state = val;
}

final rightSidebarExpandedProvider =
    NotifierProvider<RightSidebarExpandedNotifier, bool>(RightSidebarExpandedNotifier.new);
