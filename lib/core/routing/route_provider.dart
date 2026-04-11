import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRoute(String? routeName) {
    state = routeName;
  }
}

final routeProvider = NotifierProvider<RouteNotifier, String?>(() {
  return RouteNotifier();
});

class AppRouteObserver extends NavigatorObserver {
  final WidgetRef ref;
  AppRouteObserver(this.ref);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateRoute(newRoute);
  }

  void _updateRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routeProvider.notifier).setRoute(name);
    });
  }
}
