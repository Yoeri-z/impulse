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
    signal.dispose();
  }
}

/// A base class for controllers that manage the lifecycle of multiple signals and effects.
/// Controllers implement [Disposable], allowing them to be automatically cleaned up by Impulse.
abstract class Controller implements Disposable {
  bool _disposed = false;

  /// Whether or not this controller has been disposed.
  bool get disposed => _disposed;

  final _signals = HashMap.of(<int, SignalMetaData>{});
  final _effects = <EffectCleanup>[];

  @visibleForTesting
  List<EffectCleanup> get registeredEffects => _effects.toList(growable: false);

  @visibleForTesting
  List<SignalMetaData> get registeredSignals =>
      _signals.values.toList(growable: false);

  S _register<V, S extends ReadonlySignal<V>>(S target) {
    if (_signals[target.globalId] != null) {
      return target;
    }

    _signals[target.globalId] = SignalMetaData<V>(signal: target);

    return target;
  }

  /// Creates a computed signal from a list of [signals].
  @protected
  FutureSignal<V> createComputedFrom<V, A>(
    List<ReadonlySignal<A>> signals,
    Future<V> Function(List<A> args) fn, {
    AsyncSignalOptions<V>? options,
  }) {
    return _register(computedFrom<V, A>(signals, fn, options: options));
  }

  /// Creates an asynchronous computed signal.
  @protected
  FutureSignal<V> createComputedAsync<V>(
    Future<V> Function() fn, {
    AsyncSignalOptions<V>? options,
  }) {
    return _register(computedAsync<V>(fn, options: options));
  }

  /// Creates a future-based signal.
  @protected
  FutureSignal<V> createFutureSignal<V>(
    Future<V> Function() fn, {
    AsyncSignalOptions<V>? options,
  }) {
    return _register(futureSignal<V>(fn, options: options));
  }

  /// Creates a stream-based signal.
  @protected
  StreamSignal<V> createStreamSignal<V>(
    Stream<V> Function() callback, {
    AsyncSignalOptions<V>? options,
  }) {
    return _register(streamSignal<V>(callback, options: options));
  }

  /// Creates an asynchronous signal with an initial [value].
  @protected
  AsyncSignal<V> createAsyncSignal<V>(
    AsyncState<V> value, {
    AsyncSignalOptions<V>? options,
  }) {
    return _register(asyncSignal<V>(value, options: options));
  }

  /// Creates a standard signal with an initial value [val].
  @protected
  FlutterSignal<V> createSignal<V>(V val, {SignalOptions<V>? options}) {
    return _register(signal<V>(val, options: options));
  }

  /// Creates a list-based signal.
  @protected
  ListSignal<V> createListSignal<V>(
    List<V> list, {
    ListSignalOptions<V>? options,
  }) {
    return _register(ListSignal<V>(list, options: options));
  }

  /// Creates a set-based signal.
  @protected
  SetSignal<V> createSetSignal<V>(Set<V> set, {SetSignalOptions<V>? options}) {
    return _register(SetSignal<V>(set, options: options));
  }

  /// Creates a queue-based signal.'
  @protected
  QueueSignal<V> createQueueSignal<V>(
    Queue<V> queue, {
    QueueSignalOptions<V>? options,
  }) {
    return _register(QueueSignal<V>(queue, options: options));
  }

  /// Creates a map-based signal.
  @protected
  MapSignal<K, V> createMapSignal<K, V>(
    Map<K, V> value, {
    MapSignalOptions<K, V>? options,
  }) {
    return _register(MapSignal<K, V>(value, options: options));
  }

  /// Creates a computed signal.
  @protected
  FlutterComputed<V> createComputed<V>(
    V Function() cb, {
    ComputedOptions<V>? options,
  }) {
    return _register(computed<V>(cb, options: options));
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
    _disposed = true;
  }
}
