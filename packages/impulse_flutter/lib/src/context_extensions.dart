import 'package:flutter/material.dart';

import 'package:impulse/impulse.dart' hide $store;

import 'store_scope.dart';

/// Extensions on [BuildContext] to interact with an [Impulse] store.
extension GetContext on BuildContext {
  /// Retrieves the value of a [ref] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  ///
  /// Will automatically throw errors in debug mode when dangling references are detected.
  T read<T>(ImpulseReference<T> ref) {
    final store = StoreScope.of(this, depend: false);

    final box = store.box(ref);

    assert(() {
      if (ref.keepAlive || box.disposed) return true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (box.debugReferenceCount > 0) return;

        throw FlutterError.fromParts([
          ErrorSummary(
            'Impulse: Lifecycle violation attempting to read an inactive reference.',
          ),
          ErrorDescription(
            'You tried to call context.read() on a reference of type ${ref.runtimeType} '
            'that has not been initialized or bound to the widget tree.',
          ),
          ErrorHint(
            'Because this reference has a dynamic lifetime, reading it blindly outside '
            'the UI tree will instantiate it with a reference count of 0, potentially causing'
            'silent memory leaks.',
          ),
          ErrorHint(
            'To fix this, consider one of the following approaches:\n'
            '  1. If this state belongs to the UI, use "context.use(ref)" inside the build method instead.\n'
            '  2. If this is a global service that should live forever, use SingletonRef or FactoryRef when defining the reference.\n'
            '  3. If this object shouldn\'t cache state at all, change its definition to a FactoryRef.',
          ),
        ]);
      });

      return true;
    }());

    return box.produce();
  }
}

/// Extensions on [BuildContext] to bind widgets to [Impulse] references.
extension BindContext on BuildContext {
  /// Binds the current widget to a [ref] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  T use<T>(ImpulseReference<T> ref) {
    final box = StoreScope.box(this, ref);

    return box.produce();
  }
}
