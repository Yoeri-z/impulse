import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:impulse_flutter/impulse_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// A function used to onDispose of a value.
typedef DisposeValue<T> = void Function(T);

/// Metadata for a signal managed by a [Controller], including its disposal logic.
class SignalMetaData<T> {
  /// Creates [SignalMetaData] for a [signal].
  const SignalMetaData({required this.signal, this.onDispose});

  /// The managed signal.
  final ReadonlySignal<T> signal;

  /// An optional disposal callback.
  final DisposeValue<T>? onDispose;

  /// Disposes of the signal and calls the [onDispose] callback if provided.
  void disposeSignal() {
    try {
      if (signal.isInitialized &&
          (signal is! AsyncSignal ||
              (signal as AsyncSignal).internalValue.hasValue)) {
        onDispose?.call(signal.peek());
      }
    } finally {
      signal.dispose();
    }
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
    DisposeValue<V>? onDispose,
  }) {
    if (_signals[target.globalId] != null) {
      return target;
    }

    _signals[target.globalId] = SignalMetaData<V>(
      signal: target,
      onDispose: onDispose,
    );

    return target;
  }

  /// Creates a computed signal from a list of [signals].
  @protected
  FutureSignal<V> createComputedFrom<V, A>(
    List<ReadonlySignal<A>> signals,
    Future<V> Function(List<A> args) fn, {
    DisposeValue<AsyncState<V>>? onDispose,
    AsyncSignalOptions<V>? options,
  }) {
    return _register(
      computedFrom<V, A>(signals, fn, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates an asynchronous computed signal.
  @protected
  FutureSignal<V> createComputedAsync<V>(
    Future<V> Function() fn, {
    V? initialValue,
    DisposeValue<AsyncState<V>>? onDispose,
    String? debugLabel,
    List<ReadonlySignal<dynamic>> dependencies = const [],
    bool lazy = true,
  }) {
    return _register(
      computedAsync<V>(
        fn,
        options: AsyncSignalOptions(
          name: debugLabel,
          initialValue: initialValue,
          lazy: lazy,
          dependencies: dependencies,
        ),
      ),
      onDispose: onDispose,
    );
  }

  /// Creates a future-based signal.
  @protected
  FutureSignal<V> createFutureSignal<V>(
    Future<V> Function() fn, {
    DisposeValue<AsyncState<V>>? onDispose,
    AsyncSignalOptions<V>? options,
  }) {
    return _register(
      futureSignal<V>(fn, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates a stream-based signal.
  @protected
  StreamSignal<V> createStreamSignal<V>(
    Stream<V> Function() callback, {
    AsyncSignalOptions<V>? options,
    DisposeValue<AsyncState<V>>? onDispose,
  }) {
    return _register(
      streamSignal<V>(callback, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates an asynchronous signal with an initial [value].
  @protected
  AsyncSignal<V> createAsyncSignal<V>(
    AsyncState<V> value, {
    DisposeValue<AsyncState<V>>? onDispose,
    AsyncSignalOptions<V>? options,
  }) {
    return _register(
      asyncSignal<V>(value, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates a standard signal with an initial value [val].
  @protected
  FlutterSignal<V> createSignal<V>(
    V val, {
    DisposeValue<V>? onDispose,
    SignalOptions<V>? options,
  }) {
    return _register(signal<V>(val, options: options), onDispose: onDispose);
  }

  /// Creates a list-based signal.
  @protected
  ListSignal<V> createListSignal<V>(
    List<V> list, {
    DisposeValue<List<V>>? onDispose,
    ListSignalOptions<V>? options,
  }) {
    return _register(
      ListSignal<V>(list, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates a set-based signal.
  @protected
  SetSignal<V> createSetSignal<V>(
    Set<V> set, {
    DisposeValue<Set<V>>? onDispose,
    SetSignalOptions<V>? options,
  }) {
    return _register(SetSignal<V>(set, options: options), onDispose: onDispose);
  }

  /// Creates a queue-based signal.'
  @protected
  QueueSignal<V> createQueueSignal<V>(
    Queue<V> queue, {
    DisposeValue<Queue<V>>? onDispose,
    QueueSignalOptions<V>? options,
  }) {
    return _register(
      QueueSignal<V>(queue, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates a map-based signal.
  @protected
  MapSignal<K, V> createMapSignal<K, V>(
    Map<K, V> value, {
    DisposeValue<Map<K, V>>? onDispose,
    MapSignalOptions<K, V>? options,
  }) {
    return _register(
      MapSignal<K, V>(value, options: options),
      onDispose: onDispose,
    );
  }

  /// Creates a computed signal.
  @protected
  FlutterComputed<V> createComputed<V>(
    V Function() cb, {
    DisposeValue<V>? onDispose,
    ComputedOptions<V>? options,
  }) {
    return _register(computed<V>(cb, options: options), onDispose: onDispose);
  }

  /// Creates an effect and registers it for automatic disposal.
  @protected
  EffectCleanup createEffect(dynamic Function() cb, {EffectOptions? options}) {
    final s = effect(cb, options: options);
    _effects.add(s);
    return () {
      _effects.remove(s);
      s();
    };
  }

  /// Disposes of all registered signals and effects.
  @internal
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
