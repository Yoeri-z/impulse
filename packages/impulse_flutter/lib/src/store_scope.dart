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
  static ImpulseBox<T> registerDependency<T>(
    BuildContext context,
    ImpulseReference<T> ref,
  ) {
    final storeElement =
        context.getElementForInheritedWidgetOfExactType<_InheritedStore>()
            as _InheritedStoreElement?;

    if (storeElement == null) {
      throw _scopeNotFound();
    }

    if (!_tryDepend(context)) {
      throw StateError(
        '`context.of` should only be called when the widget is active'
        'try moving the call or using `context.peek`',
      );
    }

    final storeWidget = storeElement.widget as _InheritedStore;

    final element = context as Element;

    if (!storeElement.hasRegisteredDisposalForElement(element, ref.key)) {
      final dispose = storeWidget.store.watch(
        ref,
        (_) {
          // The unbind is deferred until the end of the frame, so a late
          // notification can still arrive after the element was unmounted.
          if (element.mounted) element.markNeedsBuild();
        },
      );

      storeElement.registerDisposal(element, ref.key, dispose);
    }

    return storeWidget.store.box(ref);
  }

  static StateError _scopeNotFound() {
    return StateError(
      'Could not find a `StoreScope` ancestor, make sure you wrap the widget tree with a `StoreScope` widget',
    );
  }

  /// Retrieve the store from [context].
  ///
  /// if [depend] is true (the default) the widget will be registered
  /// as a dependent and rebuild whenever the store object gets replaced.
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
  late var _store = widget.store ?? createStore();

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
    if (oldWidget.store == null) _store.reset();

    if (widget.store == null) {
      _store = createStore();
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

typedef _KeyDisposal = ({Object key, VoidCallback dispose});

class _InheritedStoreElement extends InheritedElement {
  _InheritedStoreElement(super.widget);

  final _disposeHooks = HashMap<Element, List<_KeyDisposal>>();
  final _teardownCandidates = HashSet<Element>();
  var _teardownScheduled = false;

  bool hasRegisteredDisposalForElement(Element element, Object key) {
    final hooks = _disposeHooks[element];

    if (hooks == null) return false;

    return hooks.any((hook) => hook.key == key);
  }

  void registerDisposal(Element element, Object key, VoidCallback dispose) {
    final hooks = _disposeHooks.putIfAbsent(element, () => <_KeyDisposal>[]);

    if (hooks.any((hook) => hook.key == key)) return;

    hooks.add((key: key, dispose: dispose));
  }

  void _scheduleTeardown() {
    if (_teardownScheduled) return;
    _teardownScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _teardownScheduled = false;
      _settleTeardowns();
    });
  }

  void _settleTeardowns() {
    final candidates = _teardownCandidates.toList();
    _teardownCandidates.clear();

    for (final element in candidates) {
      // Elements reactivated within the frame (e.g. by a GlobalKey move) never
      // truly left and must keep their binding.
      if (element.mounted) continue;

      final hooks = _disposeHooks.remove(element);
      if (hooks == null) continue;

      for (final hook in hooks) {
        hook.dispose();
      }
    }
  }

  @override
  void updated(_InheritedStore oldWidget) {
    if ((widget as _InheritedStore).updateShouldNotify(oldWidget)) {
      for (final hooks in _disposeHooks.values) {
        for (final hook in hooks) {
          hook.dispose();
        }
      }
      _disposeHooks.clear();
      _teardownCandidates.clear();
      super.updated(oldWidget);
    }
  }

  @override
  void removeDependent(Element dependent) {
    // Flutter calls this on every deactivation, including transient ones such
    // as GlobalKey moves. The unbind is deferred to the end of the frame so an
    // element that comes back in the same frame never loses its binding.
    _teardownCandidates.add(dependent);
    _scheduleTeardown();

    super.removeDependent(dependent);
  }
}
