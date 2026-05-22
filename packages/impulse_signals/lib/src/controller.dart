import 'dart:collection';

import 'package:flutter/cupertino.dart';

import 'package:impulse_flutter/impulse_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// A function used to dispose of a value.
typedef DisposeValue<T> = void Function(T);

/// Metadata for a signal managed by a [Controller], including its disposal logic.
class SignalMetaData<T> {
  /// Creates [SignalMetaData] for a [signal].
  const SignalMetaData({required this.signal, this.dispose});

  /// The managed signal.
  final ReadonlySignal<T> signal;

  /// An optional disposal callback.
  final DisposeValue<T>? dispose;

  /// Disposes of the signal and calls the [dispose] callback if provided.
  void disposeSignal() {
    dispose?.call(signal.peek());
    signal.dispose();
  }
}

/// A base class for controllers that manage the lifecycle of multiple signals and effects.
/// Controllers implement [Disposable], allowing them to be automatically cleaned up by Impulse.
abstract class Controller implements Disposable {
  /// Whether this controller has been disposed.
  bool disposed = false;

  final _signals = HashMap.of(<int, SignalMetaData>{});
  final _effects = <EffectCleanup>[];

  @visibleForTesting
  List<EffectCleanup> get registeredEffects => _effects.toList(growable: false);

  @visibleForTesting
  List<SignalMetaData> get registeredSignals =>
      _signals.values.toList(growable: false);

  S _register<V, S extends ReadonlySignal<V>>(
    S target, {
    DisposeValue<V>? dispose,
  }) {
    if (_signals[target.globalId] != null) {
      return target;
    }

    _signals[target.globalId] = SignalMetaData<V>(
      signal: target,
      dispose: dispose,
    );

    return target;
  }

  /// Creates a computed signal from a list of [signals].
  FutureSignal<V> createComputedFrom<V, A>(
    List<ReadonlySignal<A>> signals,
    Future<V> Function(List<A> args) fn, {
    V? initialValue,
    DisposeValue<AsyncState<V>>? dispose,
    String? debugLabel,
    bool lazy = true,
  }) {
    return _register(
      computedFrom<V, A>(
        signals,
        fn,
        initialValue: initialValue,
        debugLabel: debugLabel,
        lazy: lazy,
      ),
      dispose: dispose,
    );
  }

  /// Creates an asynchronous computed signal.
  FutureSignal<V> createComputedAsync<V>(
    Future<V> Function() fn, {
    V? initialValue,
    DisposeValue<AsyncState<V>>? dispose,
    String? debugLabel,
    List<ReadonlySignal<dynamic>> dependencies = const [],
    bool lazy = true,
  }) {
    return _register(
      computedAsync<V>(
        fn,
        dependencies: dependencies,
        initialValue: initialValue,
        debugLabel: debugLabel,
        lazy: lazy,
      ),
      dispose: dispose,
    );
  }

  /// Creates a future-based signal.
  FutureSignal<V> createFutureSignal<V>(
    Future<V> Function() fn, {
    V? initialValue,
    DisposeValue<AsyncState<V>>? dispose,
    String? debugLabel,
    List<ReadonlySignal<dynamic>> dependencies = const [],
    bool lazy = true,
  }) {
    return _register(
      futureSignal<V>(
        fn,
        initialValue: initialValue,
        debugLabel: debugLabel,
        dependencies: dependencies,
        lazy: lazy,
      ),
      dispose: dispose,
    );
  }

  /// Creates a stream-based signal.
  StreamSignal<V> createStreamSignal<V>(
    Stream<V> Function() callback, {
    V? initialValue,
    DisposeValue<AsyncState<V>>? dispose,
    String? debugLabel,
    List<ReadonlySignal<dynamic>> dependencies = const [],
    void Function()? onDone,
    bool? cancelOnError,
    bool lazy = true,
  }) {
    return _register(
      streamSignal<V>(
        callback,
        initialValue: initialValue,
        debugLabel: debugLabel,
        dependencies: dependencies,
        onDone: onDone,
        cancelOnError: cancelOnError,
        lazy: lazy,
      ),
      dispose: dispose,
    );
  }

  /// Creates an asynchronous signal with an initial [value].
  AsyncSignal<V> createAsyncSignal<V>(
    AsyncState<V> value, {
    DisposeValue<AsyncState<V>>? dispose,
    String? debugLabel,
  }) {
    return _register(
      asyncSignal<V>(value, debugLabel: debugLabel),
      dispose: dispose,
    );
  }

  /// Creates a standard signal with an initial value [val].
  FlutterSignal<V> createSignal<V>(
    V val, {
    DisposeValue<V>? dispose,
    String? debugLabel,
  }) {
    return _register(signal<V>(val, debugLabel: debugLabel), dispose: dispose);
  }

  /// Creates a list-based signal.
  ListSignal<V> createListSignal<V>(
    List<V> list, {
    DisposeValue<List<V>>? dispose,
    String? debugLabel,
  }) {
    return _register(
      ListSignal<V>(list, debugLabel: debugLabel),
      dispose: dispose,
    );
  }

  /// Creates a set-based signal.
  SetSignal<V> createSetSignal<V>(
    Set<V> set, {
    DisposeValue<Set<V>>? dispose,
    String? debugLabel,
  }) {
    return _register(
      SetSignal<V>(set, debugLabel: debugLabel),
      dispose: dispose,
    );
  }

  /// Creates a queue-based signal.
  QueueSignal<V> createQueueSignal<V>(
    Queue<V> queue, {
    DisposeValue<Queue<V>>? dispose,
    String? debugLabel,
  }) {
    return _register(
      QueueSignal<V>(queue, debugLabel: debugLabel),
      dispose: dispose,
    );
  }

  /// Creates a map-based signal.
  MapSignal<K, V> createMapSignal<K, V>(
    Map<K, V> value, {
    DisposeValue<Map<K, V>>? dispose,
    String? debugLabel,
  }) {
    return _register(
      MapSignal<K, V>(value, debugLabel: debugLabel),
      dispose: dispose,
    );
  }

  /// Creates a computed signal.
  FlutterComputed<V> createComputed<V>(
    V Function() cb, {
    DisposeValue<V>? dispose,
    String? debugLabel,
  }) {
    return _register(computed<V>(cb, debugLabel: debugLabel), dispose: dispose);
  }

  /// Creates an effect and registers it for automatic disposal.
  EffectCleanup createEffect(
    dynamic Function() cb, {
    String? debugLabel,
    dynamic Function()? onDispose,
  }) {
    final s = effect(cb, debugLabel: debugLabel, onDispose: onDispose);
    _effects.add(s);
    return () {
      _effects.remove(s);
      s();
    };
  }

  /// Disposes of all registered signals and effects.
  void clearSignalsAndEffects() {
    final signals = _signals.values;

    for (final meta in signals) {
      meta.disposeSignal();
    }
    for (final cb in _effects) {
      cb();
    }
    _effects.clear();
    _signals.clear();
  }

  @override
  void dispose() {
    clearSignalsAndEffects();
    disposed = true;
  }
}
