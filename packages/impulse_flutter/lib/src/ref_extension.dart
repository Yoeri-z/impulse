import 'package:flutter/widgets.dart';

import 'package:impulse/impulse.dart';

import 'context_extensions.dart';

extension BindRefContext<T> on Ref<T> {
  /// Retrieves the value of this [Ref] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  T peek(BuildContext context) {
    return context.peek(this());
  }

  /// Binds the current widget to this [Ref] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  /// Can only be called if the widget is currently active.
  T of(BuildContext context) {
    return context.dependOn(this());
  }
}

extension BindFamilyRefContext<T, R> on FamilyRef<T, R> {
  /// Retrieves the value of this [FamilyRef] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  T peek(BuildContext context, R param) {
    return context.peek(this(param));
  }

  /// Binds the current widget to this [FamilyRef] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  /// Can only be called if the widget is currently active.
  T of(BuildContext context, R param) {
    return context.dependOn(this(param));
  }
}

extension BindFactoryRefContext<T> on FactoryRef<T> {
  /// Retrieves the value of this [FactoryRef] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  T peek(BuildContext context) {
    return context.peek(this());
  }

  /// Binds the current widget to this [FactoryRef] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  /// Can only be called if the widget is currently active.
  T of(BuildContext context) {
    return context.dependOn(this());
  }
}
