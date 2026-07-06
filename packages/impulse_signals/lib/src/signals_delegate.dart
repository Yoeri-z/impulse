import 'package:flutter/foundation.dart';

import 'package:impulse_flutter/impulse_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// The global default [Store] instance configured for Signals.
final $store = createStore();

/// Creates a [Store] configured for `signals_flutter`.
Store createStore() => Store(delegate: SignalsReactivityDelegate());

/// A [ReactivityDelegate] pre-configured with [SignalsAdapter] to support signals.
class SignalsReactivityDelegate<T> extends ReactivityDelegate {
  /// Creates a [SignalsReactivityDelegate] with optional [adapters].
  SignalsReactivityDelegate({List<ReactivityAdapter>? adapters})
    : super(adapters: [...?adapters, SignalsAdapter()]);
}

/// A [ReactivityAdapter] that handles Signals and Notifiers.
///
/// It disables reactivity for signals but keept it for all other [ChangeNotifier]s
class SignalsAdapter implements ReactivityAdapter {
  @override
  void Function()? onBind(value, void Function() notify) {
    if (value is FlutterReadonlySignal) {
      return null;
    }

    if (value is Listenable) {
      value.addListener(notify);

      return () => value.removeListener(notify);
    }

    return null;
  }

  @override
  void onDispose(Store store, value) {
    if (value is ReadonlySignal) {
      value.dispose();
    } else if (value is ChangeNotifier) {
      value.dispose();
    }
  }
}
