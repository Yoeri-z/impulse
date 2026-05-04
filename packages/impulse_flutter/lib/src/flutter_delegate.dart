import 'package:flutter/foundation.dart';
import 'package:impulse/impulse.dart' hide $store;

/// The global default [Store] instance configured for Flutter.
final $store = Store(delegate: FlutterReactivityDelegate());

/// A [ReactivityDelegate] pre-configured with [FlutterAdapter] to support [Listenable] and [ChangeNotifier].
class FlutterReactivityDelegate<T> extends ReactivityDelegate {
  /// Creates a [FlutterReactivityDelegate] with optional [adapters].
  FlutterReactivityDelegate({List<ReactivityAdapter>? adapters})
    : super(adapters: [...?adapters, FlutterAdapter()]);
}

/// A [ReactivityAdapter] that handles Flutter's [Listenable] and [ChangeNotifier].
class FlutterAdapter implements ReactivityAdapter {
  @override
  void Function()? onBind(value, void Function() notify) {
    if (value is Listenable) {
      value.addListener(notify);

      return () => value.removeListener(notify);
    }

    return null;
  }

  @override
  void onDispose(Store store, value) {
    if (value is ChangeNotifier) {
      value.dispose();
    }
  }
}
