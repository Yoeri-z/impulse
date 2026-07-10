import 'dart:async';

import '../impulse_notifier.dart';
import '../interfaces.dart';
import '../reference.dart';
import '../store.dart';
import 'state.dart';

/// Creates a [Ref] whose value is a [StreamNotifier] wrapping a subscription to
/// a stream.
///
/// Useful for handling streaming sources (websocket messages, Firestore
/// snapshots, file watchers, etc.) through the same synchronous-creation
/// model as other refs, while still exposing loading/value/error/done state
/// reactively to widgets via `use`, `Selector`, or pattern matching.
///
/// The subscription starts immediately when the ref is created.
///
/// ```dart
/// final messagesFutureRef = streamRef((store) => api.watchMessages());
///
/// // in a widget:
/// final messagesNotifier = context.use(messagesFutureRef);
/// final (messages, err) = messagesNotifier();
/// ```
Ref<StreamNotifier<T>> streamRef<T>(
  Stream<T> Function(Store store) stream, {
  void Function(T value)? onData,
  void Function(Object error, StackTrace stackTrace)? onError,
  void Function()? onDone,
}) {
  return Ref(
    (store) => StreamNotifier(
      () => stream(store),
      onData: onData,
      onError: onError,
      onDone: onDone,
    ),
  );
}

/// Wraps a subscription to a single [Stream] and exposes its
/// loading/value/error/done state reactively.
///
/// A [StreamNotifier] subscribes to [stream] immediately on construction. Use
/// [reload] to resubscribe from a clean state (clearing the previous
/// value/error first), or [refresh] to resubscribe while keeping the
/// previous value/error visible until the next event arrives (useful for
/// pull-to-refresh style UIs where you don't want the UI to flash back to a
/// loading state).
///
/// Unlike [FutureNotifier], a [StreamNotifier] can update [value] more than once over its
/// lifetime as new events arrive, and tracks whether the stream has closed
/// via [isDone].
class StreamNotifier<T> extends ImpulseNotifier
    implements AsyncStateListenable<T> {
  /// Create a [StreamNotifier] wrapping a [stream].
  StreamNotifier(this.stream, {this.onData, this.onError, this.onDone}) {
    _run();
  }

  /// The stream this task wraps. Stored rather than inlined so
  /// [reload]/[refresh] can re-invoke it and get a fresh subscription.
  final Stream<T> Function() stream;

  /// Called after each data event, before listeners are notified. Useful
  /// for side effects (logging, analytics, cache writes) that should
  /// happen once per event.
  final void Function(T value)? onData;

  /// Called after the stream emits an error, before listeners are notified.
  /// Note the stream may continue emitting further events after an error
  /// unless it also closes.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Called once the stream closes, before listeners are notified.
  final void Function()? onDone;

  AsyncState<T> _state = const AsyncState.loading();

  @override
  AsyncState<T> get state => _state;

  bool _isLoading = true;
  bool _isDone = false;
  StreamSubscription<T>? _subscription;
  Object? _ident;

  /// The most recently emitted value, or `null` if no event has arrived
  /// yet (or [reload] was used, which clears it).
  T? get value => _state.value;

  /// The most recent value, asserting that one exists. Throws if [hasValue]
  /// is false — only use this where you've already confirmed a value is
  /// present.
  T get requireValue => _state.value!;

  /// Whether a value is currently available. Note this can be true even
  /// while [isLoading] is also true, if a [refresh] is in flight and kept
  /// the previous value visible.
  bool get hasValue => _state.hasValue;

  /// The error from the most recent error event, or `null` if none has
  /// occurred (or a later data event superseded it).
  Object? get error => _state.error;

  /// Whether the most recent event was an error.
  bool get hasError => _state.hasError;

  /// The stack trace associated with [error], if any.
  StackTrace? get stackTrace => _state.stackTrace;

  /// Whether the stream is awaiting its first event. True immediately on
  /// construction, and again during [reload]/[refresh] until they emit or
  /// close.
  bool get isLoading => _isLoading;

  /// Whether the stream has closed (sent a done event). Once true, no
  /// further [value]/[error] updates will happen unless [reload] or
  /// [refresh] is called.
  bool get isDone => _isDone;

  void _run() {
    _ident = Object();
    final callIdent = _ident;
    _isDone = false;

    _subscription = stream().listen(
      (event) {
        if (disposed || callIdent != _ident) return;
        _isLoading = false;
        _state = AsyncState.data(event);
        onData?.call(event);
        notify();
      },
      onError: (Object e, StackTrace st) {
        if (disposed || callIdent != _ident) return;
        _isLoading = false;
        _state = AsyncState.error(e, st, previousValue: _state.value);
        onError?.call(e, st);
        notify();
      },
      onDone: () {
        if (disposed || callIdent != _ident) return;
        _isDone = true;
        _isLoading = false;
        onDone?.call();
        notify();
      },
    );
  }

  /// Cancels the current subscription and resubscribes to [stream],
  /// keeping the current [value]/[error] visible until the next event
  /// arrives. [isLoading] becomes true immediately.
  ///
  /// Prefer this over [reload] when the UI shouldn't flash back to an empty
  /// loading state — e.g. reconnecting a socket that already has data.
  void refresh() async {
    _isLoading = true;
    _state = AsyncState.loading(previousValue: _state.value);
    notify();
    _subscription?.cancel();
    _run();
  }

  /// Clears [value]/[error] immediately, cancels the current subscription,
  /// then resubscribes to [stream] from scratch.
  ///
  /// Prefer this when stale data shouldn't be shown at all while reloading
  /// — e.g. after changing a filter that makes the previous events invalid.
  void reload() async {
    _isLoading = true;
    _state = const AsyncState.loading();
    notify();
    _subscription?.cancel();
    _run();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
