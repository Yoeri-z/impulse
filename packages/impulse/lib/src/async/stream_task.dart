import 'dart:async';

import '../impulse_notifier.dart';
import '../reference.dart';
import '../store.dart';
import 'async_utils.dart';

/// Creates a [Ref] whose value is a [StreamTask] wrapping a subscription to
/// a stream.
///
/// Useful for handling streaming sources (websocket messages, Firestore
/// snapshots, file watchers, etc.) through the same synchronous-creation
/// model as other refs, while still exposing loading/value/error/done state
/// reactively to widgets via `use`, `Selector`, or `ResultSelector`.
///
/// The subscription starts immediately when the ref is created.
///
/// ```dart
/// final messagesTaskRef = streamTaskRef((store) => api.watchMessages());
///
/// // in a widget:
/// ResultSelector(
///   ref: messagesTaskRef,
///   selector: (task) => task.result,
///   nothingBuilder: (context) => CircularProgressIndicator(),
///   resultBuilder: (context, messages) => Text(messages.last),
///   errBuilder: (context, err) => Text(err.toString()),
/// )
/// ```
Ref<StreamTask<T>> streamRef<T>(
  Stream<T> Function(Store store) stream, {
  void Function(T value)? onData,
  void Function(Object error, StackTrace stackTrace)? onError,
  void Function()? onDone,
}) {
  return Ref(
    (store) => StreamTask(
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
/// A [StreamTask] subscribes to [stream] immediately on construction. Use
/// [reload] to resubscribe from a clean state (clearing the previous
/// value/error first), or [refresh] to resubscribe while keeping the
/// previous value/error visible until the next event arrives (useful for
/// pull-to-refresh style UIs where you don't want the UI to flash back to a
/// loading state).
///
/// Unlike [Task], a [StreamTask] can update [value] more than once over its
/// lifetime as new events arrive, and tracks whether the stream has closed
/// via [isDone].
class StreamTask<T> extends ImpulseNotifier {
  /// Create a [StreamTask] wrapping a [stream].
  StreamTask(this.stream, {this.onData, this.onError, this.onDone}) {
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

  T? _value;
  Object? _error;
  StackTrace? _stackTrace;
  bool _isLoading = true;
  bool _isDone = false;
  StreamSubscription<T>? _subscription;
  Object? _ident;

  /// The most recently emitted value, or `null` if no event has arrived
  /// yet (or [reload] was used, which clears it).
  T? get value => _value;

  /// The most recent value, asserting that one exists. Throws if [hasValue]
  /// is false — only use this where you've already confirmed a value is
  /// present.
  T get requireValue => _value!;

  /// Whether a value is currently available. Note this can be true even
  /// while [isLoading] is also true, if a [refresh] is in flight and kept
  /// the previous value visible.
  bool get hasValue => _value != null;

  /// The error from the most recent error event, or `null` if none has
  /// occurred (or a later data event superseded it).
  Object? get error => _error;

  /// Whether the most recent event was an error.
  bool get hasError => _error != null;

  /// The stack trace associated with [error], if any.
  StackTrace? get stackTrace => _stackTrace;

  /// Whether the stream is awaiting its first event. True immediately on
  /// construction, and again during [reload]/[refresh] until they emit or
  /// close.
  bool get isLoading => _isLoading;

  /// Whether the stream has closed (sent a done event). Once true, no
  /// further [value]/[error] updates will happen unless [reload] or
  /// [refresh] is called.
  bool get isDone => _isDone;

  /// A snapshot of ([value], [error]) suitable for destructuring, e.g.
  /// `final (value, err) = task.asResult;`.
  Result<T> get asResult =>
      (_value, hasError ? Err(_error!, _stackTrace!) : null);

  void _run() {
    _ident = Object();
    final callIdent = _ident;
    _isDone = false;

    _subscription = stream().listen(
      (event) {
        if (disposed || callIdent != _ident) return;
        _value = event;
        _error = null;
        _stackTrace = null;
        _isLoading = false;
        onData?.call(event);
        notify();
      },
      onError: (Object e, StackTrace st) {
        if (disposed || callIdent != _ident) return;
        _error = e;
        _stackTrace = st;
        _isLoading = false;
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
    _value = null;
    _error = null;
    _stackTrace = null;
    _isLoading = true;
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
