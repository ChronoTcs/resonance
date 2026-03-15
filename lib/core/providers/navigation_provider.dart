import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Provider to manage the global navigation state (currently active tab in MainDashboard)
final mainNavigationProvider = NotifierProvider<MainNavigationNotifier, int>(() {
  return MainNavigationNotifier();
});
