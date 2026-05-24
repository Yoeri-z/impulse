import 'package:flutter/widgets.dart';

import 'package:impulse/impulse.dart';

import 'context_extensions.dart';

/// provides [read] and [bind] for keyless references
extension RefContext<T> on KeylessRef<T> {
  /// Retrieves the value of this [Ref] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  T read(BuildContext context) {
    return context.read(this());
  }

  /// Binds the current widget to this [Ref] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  /// Can only be called if the widget is currently active.
  T bind(BuildContext context) {
    return context.bind(this());
  }
}

/// provides [read] and [bind] for family references
extension FamilyRefContext<T, R> on FamilyRef<T, R> {
  /// Retrieves the value of this [FamilyRef] from the nearest [StoreScope].
  /// This does not create a dependency, so the widget will not rebuild when the value changes.
  T read(BuildContext context, R param) {
    return context.read(this(param));
  }

  /// Binds the current widget to this [FamilyRef] from the nearest [StoreScope].
  /// The widget will automatically rebuild whenever the reference notifies of a change.
  /// Can only be called if the widget is currently active.
  T bind(BuildContext context, R param) {
    return context.bind(this(param));
  }
}
