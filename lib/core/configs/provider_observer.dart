import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

base class AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is AsyncError) {
      dev.log(
        'Provider Error: ${context.provider.name ?? context.provider.runtimeType}',
        error: newValue.error,
        stackTrace: newValue.stackTrace,
        name: 'RiverpodObserver',
      );
    }
  }

  @override
  void didAddProvider(
    ProviderObserverContext context,
    Object? value,
  ) {
    dev.log(
      'Provider Added: ${context.provider.name ?? context.provider.runtimeType}',
      name: 'RiverpodObserver',
    );
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    dev.log(
      'Provider Failed: ${context.provider.name ?? context.provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
      name: 'RiverpodObserver',
    );
  }
}
