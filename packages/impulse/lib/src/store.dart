import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'reactivity_delegate.dart';
import 'box.dart';
import 'reference.dart';

/// The global default [Store] instance.
final $store = Store();

/// A central container for managing shared state and dependencies.
class Store {
  /// Creates a [Store] with an optional [delegate].
  Store({ReactivityDelegate? delegate})
    : reactivity = delegate ?? ReactivityDelegate();

  /// The delegate used to handle reactivity and disposal for objects in this store.
  final ReactivityDelegate reactivity;
  final _store = HashMap<Object, ImpulseBox>();

  /// Returns an unmodifiable view of the currently registered boxes in the store.
  Map<Object, ImpulseBox> get boxes => UnmodifiableMapView(_store);

  @internal
  ImpulseBox? activeEvaluationBox;

  /// Retrieves the [ImpulseBox] associated with a [ref], creating it if it doesn't exist.
  ImpulseBox<T> box<T>(ImpulseReference<T> ref) {
    final box =
        _store.putIfAbsent(
              ref.key,
              () => ImpulseBox<T>(ref: ref, store: this, delegate: reactivity),
            )
            as ImpulseBox<T>;

    return box;
  }

  /// Checks if a [ref] currently exists in the store.
  bool exists<T>(ImpulseReference<T> ref) {
    return _store.containsKey(ref.key);
  }

  /// Alias for [get], doesnt return a value but just initializes the reference
  void init<T>(ImpulseReference<T> ref) {
    get<T>(ref);
  }

  /// Retrieves the value of a [ref]. Initializes the object if it hasn't been created yet.
  T get<T>(ImpulseReference<T> ref) {
    final box = this.box<T>(ref);

    return box.produce();
  }

  /// Watches a [ref] for changes. The [watch] callback is called whenever the object notifies.
  /// Returns a function to stop watching.
  ///
  /// Automatically disposes [ref] when nothing is watching it.
  void Function() watch<T>(ImpulseReference<T> ref, void Function(T) watch) {
    final box = this.box<T>(ref);

    void listener() {
      watch(box.produce());
    }

    box.retain();
    box.addListener(listener);

    return () {
      box.removeListener(listener);
      box.release();
    };
  }

  /// Watches a [ref] for changes and filters the output through [select].
  /// Will only fire [watch] when the [select] value is different through comparison.
  void Function() select<T, R>(
    ImpulseReference<T> ref,
    R Function(T) select,
    void Function(R) watch, {
    bool onlyOnDependencyChange = false,
  }) {
    R? oldValue;

    return this.watch(ref, (object) {
      final value = select(object);

      if (oldValue == value) return;

      oldValue = value;

      watch(value);
    });
  }

  /// Removes a [ref] and its associated object from the store, disposing of it.
  void drop<T>(ImpulseReference<T> ref) {
    final box = _store.remove(ref.key);

    box?.dispose();
  }

  /// Tells each box to reassemble
  /// essentially this retracks dependencies without losing state
  void reassemble() {
    final boxes = _store.values.toList();

    for (final box in boxes) {
      box.reassemble();
    }
  }

  /// Override the value of reference with a new value.
  /// This will prompt all dependents to recreate.
  ///
  /// Mainly usefull for testing.
  void override<T>(ImpulseReference<T> ref, Create<T> create) {
    box(ref).overrideWith(create);
  }

  /// Remove override from the given [ref] if present.
  /// This will prompt all dependents to recreate.
  ///
  /// Mainly usefull for testing.
  void removeOverride<T>(ImpulseReference<T> ref) {
    box(ref).removeOverride();
  }

  /// Disposes of all objects in the store and clears it.
  void reset() {
    final boxes = _store.values.toList();

    _store.clear();

    for (final box in boxes) {
      box.dispose();
    }
  }

  /// Runs a [callback] within a scope that retains a [ref].
  /// The [ref] is automatically released when the callback finishes.
  Future<T> withScope<T, R>(
    ImpulseReference<R> ref,
    FutureOr<T> Function(Store store, R value) callback,
  ) async {
    final box = this.box(ref);
    box.retain();

    try {
      return await callback(this, box.produce());
    } finally {
      box.release();
    }
  }
}
