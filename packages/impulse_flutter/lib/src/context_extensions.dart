import 'package:flutter/material.dart';

import 'package:impulse/impulse.dart' hide $store;

import 'store_scope.dart';

/// Extensions on [BuildContext] to interact with an [Impulse] store.
extension GetContext on BuildContext {
  /// Retrieves the value of a [ref] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  T read<T>(ImpulseReference<T> ref) {
    final box = StoreScope.box(this, ref, depend: false);

    return box.produce();
  }
}

/// Extensions on [BuildContext] to bind widgets to [Impulse] references.
extension BindContext on BuildContext {
  /// Binds the current widget to a [ref] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  T bind<T>(ImpulseReference<T> ref) {
    final box = StoreScope.box(this, ref, depend: true);

    return box.produce();
  }
}
