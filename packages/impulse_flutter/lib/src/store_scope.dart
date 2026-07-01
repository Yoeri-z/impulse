import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:impulse/impulse.dart' hide $store;

import 'flutter_delegate.dart';

/// A widget that provides a [Store] to its descendants.
///
/// If [store] is not provided, the global [$store] will be used.
class StoreScope extends StatefulWidget {
  /// Creates a [StoreScope] that wraps a [child].
  /// If [store] is not provided, the global [$store] is used.
  const StoreScope({super.key, this.store, required this.child});

  /// The store instance to be used by this scope.
  ///
  /// if none is provided it will use the global [$store]
  final Store? store;

  /// The widget tree below this scope.
  final Widget child;

  static bool _tryDepend(BuildContext context) {
    try {
      context.dependOnInheritedWidgetOfExactType<_InheritedStore>();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves an [ImpulseBox] from the nearest [StoreScope] ancestor.
  /// the calling [context] will be bound to the reference.
  static ImpulseBox<T> box<T>(BuildContext context, ImpulseReference<T> ref) {
    final storeElement =
        context.getElementForInheritedWidgetOfExactType<_InheritedStore>()
            as _InheritedStoreElement?;

    if (storeElement == null) {
      throw _scopeNotFound();
    }

    final storeWidget = storeElement.widget as _InheritedStore;

    final box = storeWidget.store.box(ref);

    if (!_tryDepend(context)) {
      throw StateError(
        '`context.of` should only be called when the widget is active'
        'try moving the call or using `context.peek`',
      );
    }

    final element = context as Element;

    if (!storeElement.hasRegisteredDisposalForElement(element, box.ref.key)) {
      void listener() => element.markNeedsBuild();
      void dispose() {
        if (!box.disposed) {
          box.removeListener(listener);
          box.release();
        }
      }

      box.retain();
      box.addListener(listener);

      storeElement.registerDisposal(element, box.ref.key, dispose);
    }

    return box;
  }

  static StateError _scopeNotFound() {
    return StateError(
      'Could not find a `StoreScope` ancestor, make sure you wrap the widget tree with a `StoreScope` widget',
    );
  }

  static Store of(BuildContext context, {bool depend = true}) {
    final widget = depend
        ? context.dependOnInheritedWidgetOfExactType<_InheritedStore>()
        : context.getInheritedWidgetOfExactType<_InheritedStore>();

    if (widget == null) {
      throw _scopeNotFound();
    }

    return widget.store;
  }

  @override
  State<StoreScope> createState() => _StoreScopeState();
}

class _StoreScopeState extends State<StoreScope> {
  late var _store = widget.store ?? $store;

  @override
  void reassemble() {
    super.reassemble();
    _store.reassemble();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Store>('store', _store));
    _store.boxes.forEach((key, box) {
      final referenceCount = box.debugReferenceCount;

      properties.add(DiagnosticsProperty('ref', key.toString()));
      properties.add(DiagnosticsProperty('referers', referenceCount));
    });
  }

  @override
  void didUpdateWidget(covariant StoreScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.store == oldWidget.store) return;

    _store.reset();

    if (widget.store == null) {
      _store = $store;
    } else {
      _store = widget.store!;
    }
  }

  @override
  void dispose() {
    if (widget.store == null) _store.reset();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedStore(store: _store, child: widget.child);
  }
}

class _InheritedStore extends InheritedWidget {
  const _InheritedStore({required this.store, required super.child});

  final Store store;

  @override
  bool updateShouldNotify(_InheritedStore oldWidget) {
    return store != oldWidget.store;
  }

  @override
  _InheritedStoreElement createElement() => _InheritedStoreElement(this);
}

typedef KeyDisposal = ({Object key, VoidCallback dispose});

class _InheritedStoreElement extends InheritedElement {
  _InheritedStoreElement(super.widget);

  final _disposeHooks = HashMap<Element, List<KeyDisposal>>();

  bool hasRegisteredDisposalForElement(Element element, Object key) {
    final hooks = _disposeHooks[element];

    if (hooks == null) return false;

    return hooks.any((hook) => hook.key == key);
  }

  void registerDisposal<T>(Element element, Object key, VoidCallback dispose) {
    final hooks = _disposeHooks.putIfAbsent(element, () => <KeyDisposal>[]);

    if (hooks.any((hook) => hook.key == key)) return;

    hooks.add((key: key, dispose: dispose));
  }

  @override
  void removeDependent(Element dependent) {
    final hooks = _disposeHooks[dependent];

    if (hooks != null) {
      for (final hook in hooks) {
        hook.dispose();
      }
    }

    super.removeDependent(dependent);
  }
}
