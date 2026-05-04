import 'interfaces.dart';
import 'store.dart';

/// A delegate that manages a collection of [ReactivityAdapter]s to handle binding and disposal of various object types.
class ReactivityDelegate {
  /// Creates a [ReactivityDelegate] with an optional list of [adapters].
  /// By default, it includes adapters for [ImpulseListenable] and [Disposable].
  ReactivityDelegate({List<ReactivityAdapter>? adapters}) {
    _adapters = [...?adapters];
    addAdapter(const _ListenableAdapter());
    addAdapter(const _DisposableAdapter());
  }

  late final List<ReactivityAdapter> _adapters;

  /// Adds a new [adapter] to the delegate.
  void addAdapter(ReactivityAdapter adapter) {
    _adapters.add(adapter);
  }

  /// Iterates through all adapters to bind a [value].
  /// Returns a combined unbind function if any adapter returns one.
  void Function()? onBind(dynamic value, void Function() notify) {
    final unbinders = <void Function()>[];

    for (final adapter in _adapters) {
      final unbind = adapter.onBind(value, notify);
      if (unbind != null) {
        unbinders.add(unbind);
      }
    }

    if (unbinders.isEmpty) {
      return null;
    }

    if (unbinders.length == 1) {
      return unbinders.first;
    }

    return () {
      for (final unbind in unbinders) {
        unbind();
      }
    };
  }

  /// Iterates through all adapters to dispose of a [value].
  void onDispose(Store store, dynamic value) {
    for (final adapter in _adapters) {
      adapter.onDispose(store, value);
    }
  }
}

class _ListenableAdapter implements ReactivityAdapter {
  const _ListenableAdapter();

  @override
  void Function()? onBind(dynamic value, void Function() notify) {
    if (value is ImpulseListenable) {
      value.addListener(notify);
      return () => value.removeListener(notify);
    }

    return null;
  }

  @override
  void onDispose(Store store, dynamic value) {}
}

class _DisposableAdapter implements ReactivityAdapter {
  const _DisposableAdapter();

  @override
  void Function()? onBind(dynamic value, void Function() notify) => null;

  @override
  void onDispose(Store store, dynamic value) {
    if (value is Disposable) {
      value.dispose();
    }
  }
}
