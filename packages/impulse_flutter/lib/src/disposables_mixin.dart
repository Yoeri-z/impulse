import 'package:flutter/widgets.dart';
import 'package:impulse/impulse.dart';

import 'store_scope.dart';

/// Mixin that manages disposal of objects owned by a [State] through the
/// store's reactivity system.
///
/// Objects created with [managed] are disposed when the state is disposed.
/// Disposal goes through the store's reactivity system, so any type the
/// configured `ReactivityAdapter`s handle (such as `ChangeNotifier` or
/// [Disposable]) is disposed automatically. A custom callback can be provided
/// for anything else.
///
///```dart
/// class _MyWidgetState extends State<MyWidget> with Disposables {
///   late final textController = managed((store) => TextEditingController());
/// }
/// ```
mixin Disposables<W extends StatefulWidget> on State<W> {
  /// Creates a managed object from [create] and registers it for disposal
  /// when the state is disposed.
  ///
  /// Intended for field initializers such as
  /// `late final notifier = managed((store) => FutureNotifier(...))`. The object
  /// is created eagerly on first access and disposed when the state is
  /// disposed, or by the provided callback.
  ///
  /// The default disposal path runs [ReactivityAdapter.onDispose] for every
  /// adapter on the store. [reassemble], if provided, is an optional hook that
  /// runs when the widget tree is reassembled while hot reloading, so values
  /// derived from code under edit can be recreated or corrected.
  T managed<T>(
    Create<T> create, {
    Update<T>? reassemble,
    Dispose<T>? dispose,
    bool recreateOnReassemble = false,
  }) {
    var store = StoreScope.of(context, depend: false);

    var obj = create(store);

    if (reassemble != null) {
      _reassembles.add(() {
        if (recreateOnReassemble) {
          store.reactivity.onDispose(obj);
          store = StoreScope.of(context, depend: false);
          obj = create(store);
        }

        reassemble(obj);
      });
    }
    if (dispose != null) {
      _disposals.add(() => dispose(obj));
    } else {
      _disposals.add(() => store.reactivity.onDispose(obj));
    }

    return obj;
  }

  late final _reassembles = <VoidCallback>[];

  late final _disposals = <VoidCallback>[];

  @override
  void reassemble() {
    super.reassemble();

    for (var reassemble in _reassembles) {
      reassemble();
    }
  }

  @override
  void dispose() {
    for (final dispose in _disposals) {
      dispose();
    }

    super.dispose();
  }
}
