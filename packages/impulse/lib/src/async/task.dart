import 'dart:async';

import '../interfaces.dart';
import '../reference.dart';
import 'async_utils.dart';
import '../box.dart';
import '../store.dart';

/// Creates a [Ref] whose value is a [Task] wrapping an asynchronous call.
///
/// Useful for handling async methods (network requests, file I/O, etc.)
/// through the same synchronous-creation model as other refs, while still
/// exposing loading/value/error state reactively to widgets via `use`,
/// `Selector`, or `ResultSelector`.
///
/// The task starts executing immediately when the ref is created.
///
/// ```dart
/// final userTaskRef = taskRef((store) => api.fetchUser());
///
/// // in a widget:
/// ResultSelector(
///   ref: userTaskRef,
///   selector: (task) => task.result,
///   nothingBuilder: (context) => CircularProgressIndicator(),
///   resultBuilder: (context, user) => Text(user.name),
///   errBuilder: (context, err) => Text(err.toString()),
/// )
/// ```
Ref<Task<T>> taskRef<T>(
  Future<T> Function(Store store) task, {
  void Function(T value)? onSuccess,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return Ref(
    (store) => Task(() => task(store), onSuccess: onSuccess, onError: onError),
  );
}

/// Wraps a single asynchronous call and exposes its loading/value/error
/// state reactively.
///
/// A [Task] executes its [call] immediately on construction. Use [reload]
/// to re-run it from a clean state (clearing the previous value/error first),
/// or [refresh] to re-run it while keeping the previous value/error visible
/// until the new result arrives (useful for pull-to-refresh style UIs where
/// you don't want the UI to flash back to a loading state).
class Task<T> extends ImpulseNotifier implements ResultContainer {
  /// Create a [Task] wrapping a [call]
  Task(this.call, {this.onSuccess, this.onError}) {
    _run();
  }

  /// The async operation this task wraps. Stored rather than inlined so
  /// [reload]/[refresh] can re-invoke it.
  final Future<T> Function() call;

  /// Called after [call] completes successfully, before listeners are
  /// notified. Useful for side effects (logging, analytics, cache writes)
  /// that should happen exactly once per successful completion.
  final void Function(T value)? onSuccess;

  /// Called after [call] throws, before listeners are notified.
  final void Function(Object error, StackTrace stackTrace)? onError;

  T? _value;
  Object? _error;
  StackTrace? _stackTrace;
  bool _isLoading = true;
  Object? _ident;

  /// The most recently resolved value, or `null` if no successful
  /// completion has happened yet (or the last completion errored and
  /// [reload] was used, which clears it).
  T? get value => _value;

  /// The most recent value, asserting that one exists. Throws if [hasValue]
  /// is false — only use this where you've already confirmed a value is
  /// present.
  T get requireValue => _value!;

  /// Whether a value is currently available. Note this can be true even
  /// while [isLoading] is also true, if a [refresh] is in flight and kept
  /// the previous value visible.
  bool get hasValue => _value != null;

  /// The error from the most recent failed completion, or `null` if the
  /// last completion succeeded (or none has happened yet).
  Object? get error => _error;

  /// Whether the most recent completion ended in an error.
  bool get hasError => _error != null;

  /// The stack trace associated with [error], if any.
  StackTrace? get stackTrace => _stackTrace;

  /// Whether [call] is currently in flight. True immediately on
  /// construction, and again during [reload]/[refresh] until they resolve.
  bool get isLoading => _isLoading;

  /// A snapshot of ([value], [error]) suitable for destructuring, e.g.
  /// `final (value, err) = task.asResult;`.
  @override
  Result<T> get result =>
      (_value, hasError ? Err(_error!, _stackTrace!) : null);

  Future<void> _run() async {
    try {
      _ident = Object();
      final callIdent = _ident;
      final result = await call();

      if (disposed || callIdent != _ident) return;

      _value = result;
      _error = null;
      _stackTrace = null;
      _isLoading = false;
      onSuccess?.call(result);
      notify();
    } catch (e, st) {
      if (disposed) return;
      _error = e;
      _stackTrace = st;
      _isLoading = false;
      onError?.call(e, st);
      notify();
    }
  }

  /// Re-runs [call], keeping the current [value]/[error] visible until the
  /// new result arrives. [isLoading] becomes true immediately.
  ///
  /// Prefer this over [reload] when the UI shouldn't flash back to an empty
  /// loading state — e.g. pull-to-refresh on a list that already has data.
  Future<void> refresh() async {
    _isLoading = true;
    notify();
    await _run();
  }

  /// Clears [value]/[error] immediately, then re-runs [call] from scratch.
  ///
  /// Prefer this when stale data shouldn't be shown at all while reloading
  /// — e.g. after changing a filter that makes the previous result invalid.
  Future<void> reload() async {
    _value = null;
    _error = null;
    _stackTrace = null;
    _isLoading = true;
    notify();
    await _run();
  }
}
