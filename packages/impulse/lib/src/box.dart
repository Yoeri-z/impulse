// ignore_for_file: null_check_on_nullable_type_parameter
import 'package:meta/meta.dart';

import 'reactivity_delegate.dart';
import 'interfaces.dart';
import 'reference.dart';
import 'store.dart';

/// A container that manages the lifecycle, reactivity, and reference counting of a stored object.
class ImpulseBox<T> extends ImpulseNotifier {
  /// Creates an [ImpulseBox] for a specific [ref] in a [store].
  ImpulseBox({required this.ref, required this.store, required this.delegate});

  final ImpulseReference<T> ref;
  final Store store;
  final ReactivityDelegate delegate;

  final Set<ImpulseBox<dynamic>> _dependencies = {};
  final Set<ImpulseBox<dynamic>> _dependents = {};

  Create<T>? _override;

  Create<T> get _create => _override ?? ref.create;

  void Function()? _cancelSubscription;
  bool uninitialized = true;
  bool disposed = false;
  bool _isEvaluating = false;

  /// Exposes the internal [_value] of this [ImpulseBox]
  @visibleForTesting
  T? get debugInternalValue => _value;

  T? _value;

  int _referenceCount = 0;

  /// Returns the amount of objects currently referencing this object.
  /// This is intended for debugging and diagnostics purposes.
  int get debugReferenceCount => _referenceCount;

  @internal
  void addDependent(ImpulseBox<dynamic> dependent) =>
      _dependents.add(dependent);

  @internal
  void removeDependent(ImpulseBox<dynamic> dependent) =>
      _dependents.remove(dependent);

  void retain() {
    if (ref.keepAlive) return;
    _referenceCount++;
  }

  void release() {
    if (ref.keepAlive) return;
    _referenceCount--;
    if (_referenceCount <= 0) {
      store.drop(ref);
    }
  }

  T produce() {
    if (disposed) {
      throw StateError(
        'Tried to produce a value after box was disposed,'
        'if this is intended consider using `box.reset()` instead of `box.dispose`',
      );
    }

    if (ref.isFactory) {
      return _create(store);
    }

    if (uninitialized) {
      if (_isEvaluating) {
        throw StateError(
          'Circular dependency detected. The factory for ${ref.runtimeType} '
          'tried to read itself while it was mid-initialization.',
        );
      }

      _isEvaluating = true;
      final previousEvaluationBox = store.activeEvaluationBox;
      store.activeEvaluationBox = this;

      try {
        _bindValue(_create(store));
      } finally {
        store.activeEvaluationBox = previousEvaluationBox;
        _isEvaluating = false;
      }
    }

    final currentDependent = store.activeEvaluationBox;
    if (currentDependent != null && currentDependent != this) {
      addDependent(currentDependent);
      currentDependent._dependencies.add(this);
      retain();
    }

    return _value!;
  }

  /// Resets this box back to an uninitialized state, triggering cascading
  /// updates down to its dependents.
  void reset() {
    if (uninitialized) return;

    _teardown();
    uninitialized = true;

    notify();
    _invalidateDependents();
  }

  /// Override the value of this [ImpulseBox] with a new value.
  /// This will prompt all dependents to recreate.
  ///
  /// Mainly usefull for testing.
  void overrideWith(Create<T> newCreate) {
    _override = newCreate;

    if (!uninitialized) replace(_create(store));
  }

  /// Remove override from this [ImpulseBox] if present.
  /// This will prompt all dependents to recreate (if it was present).
  ///
  /// Mainly usefull for testing.
  void removeOverride() {
    if (_override == null) return;

    _override = null;

    if (!uninitialized) replace(_create(store));
  }

  /// Replaces the current value with a [newValue] and instantly
  /// cascades the invalidation down to all dependents.
  void replace(T newValue) {
    _teardown();

    _bindValue(newValue);

    notify();

    _invalidateDependents();
  }

  /// Resets dependencies of the box to pristine while keeping the internal state
  void reassemble() {
    if (_value == null) return;

    ref.reassemble?.call(_value!);
  }

  /// Shared internal cleanup sequence for values, streams, and upstream dependencies.
  void _teardown() {
    _cancelSubscription?.call();
    _cancelSubscription = null;

    if (_value != null) {
      delegate.onDispose(store, _value!);
      ref.dispose?.call(_value!);
      _value = null;
    }

    final targets = _dependencies.toList();

    _dependencies.clear();

    for (final dependency in targets) {
      dependency.removeDependent(this);
      dependency.release();
    }
  }

  void _invalidateDependents() {
    // this avoids concurrent modifications
    final targets = _dependents.toList();
    _dependents.clear();

    for (final dependent in targets) {
      dependent.reset();
    }
  }

  void _bindValue(T value) {
    _value = value;
    _cancelSubscription = delegate.onBind(value, notify);
    uninitialized = false;
  }

  @override
  void dispose() {
    if (disposed) return;

    _teardown();
    _invalidateDependents();

    disposed = true;
    super.dispose();
  }
}

/// A base class for objects that implement [ImpulseListenable] and [Disposable].
class ImpulseNotifier implements ImpulseListenable, Disposable {
  final _listeners = <Listener>{};

  @override
  void addListener(Listener listener) => _listeners.add(listener);

  @override
  void removeListener(Listener listener) => _listeners.remove(listener);

  /// Notifies all registered listeners of a state change.
  void notify() {
    for (var listener in _listeners) {
      listener();
    }
  }

  @override
  void dispose() {
    _listeners.clear();
  }
}
