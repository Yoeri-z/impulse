import 'dart:async';

import '../impulse_notifier.dart';
import '../interfaces.dart';
import '../reference.dart';
import '../store.dart';
import 'state.dart';

/// Creates a [Ref] whose value is a [FutureNotifier] wrapping an asynchronous call.
///
/// Useful for handling async methods (network requests, file I/O, etc.)
/// through the same synchronous-creation model as other refs, while still
/// exposing loading/value/error state reactively to widgets via `use`,
/// `Selector`, or pattern matching.
///
/// The task starts executing immediately when the ref is created.
///
/// ```dart
/// final userFutureRef = futureRef((store) => api.fetchUser());
///
/// // in a widget:
/// final userNotifier = context.use(userFutureRef);
/// final (user, err) = userNotifier();
/// ```
Ref<FutureNotifier<T>> futureRef<T>(
  Future<T> Function(Store store) future, {
  void Function(T value)? onSuccess,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return Ref(
    (store) => FutureNotifier(
      () => future(store),
      onSuccess: onSuccess,
      onError: onError,
    ),
  );
}

/// Wraps a single asynchronous call and exposes its loading/value/error
/// state reactively.
///
/// A [FutureNotifier] executes its [_call] immediately on construction. Use [reload]
/// to re-run it from a clean state (clearing the previous value/error first),
/// or [refresh] to re-run it while keeping the previous value/error visible
/// until the new result arrives (useful for pull-to-refresh style UIs where
/// you don't want the UI to flash back to a loading state).
class FutureNotifier<T> extends ImpulseNotifier
    implements AsyncStateListenable<T> {
  /// Create a [FutureNotifier] wrapping a [call]
  FutureNotifier(Future<T> Function() call, {this.onSuccess, this.onError})
    : _call = call {
    _run();
  }

  /// The async operation this task wraps. Stored rather than inlined so
  /// [reload]/[refresh] can re-invoke it.
  final Future<T> Function() _call;

  /// Called after [_call] completes successfully, before listeners are
  /// notified. Useful for side effects (logging, analytics, cache writes)
  /// that should happen exactly once per successful completion.
  final void Function(T value)? onSuccess;

  /// Called after [_call] throws, before listeners are notified.
  final void Function(Object error, StackTrace stackTrace)? onError;

  AsyncState<T> _state = const AsyncState.loading();

  @override
  AsyncState<T> get state => _state;

  Object? _ident;

  /// The most recently resolved value, or `null` if no successful
  /// completion has happened yet (or the last completion errored and
  /// [reload] was used, which clears it).
  T? get value => _state.value;

  /// The most recent value, asserting that one exists. Throws if [hasValue]
  /// is false — only use this where you've already confirmed a value is
  /// present.
  T get requireValue => _state.value!;

  /// Whether a value is currently available. Note this can be true even
  /// while [isLoading] is also true, if a [refresh] is in flight and kept
  /// the previous value visible.
  bool get hasValue => _state.hasValue;

  /// The error from the most recent failed completion, or `null` if the
  /// last completion succeeded (or none has happened yet).
  Object? get error => _state.error;

  /// Whether the most recent completion ended in an error.
  bool get hasError => _state.hasError;

  /// The stack trace associated with [error], if any.
  StackTrace? get stackTrace => _state.stackTrace;

  /// Whether [_call] is currently in flight. True immediately on
  /// construction, and again during [reload]/[refresh] until they resolve.
  bool get isLoading => _state.isLoading;

  Future<void> _run() async {
    try {
      _ident = Object();
      final callIdent = _ident;
      final result = await _call();

      if (disposed || callIdent != _ident) return;

      _state = AsyncState.data(result);
      onSuccess?.call(result);
      notify();
    } catch (e, st) {
      if (disposed) return;
      _state = AsyncState.error(e, st, previousValue: _state.value);
      onError?.call(e, st);
      notify();
    }
  }

  /// Re-runs [_call], keeping the current [value]/[error] visible until the
  /// new result arrives. [isLoading] becomes true immediately.
  ///
  /// Prefer this over [reload] when the UI shouldn't flash back to an empty
  /// loading state — e.g. pull-to-refresh on a list that already has data.
  Future<void> refresh() async {
    _state = AsyncState.loading(previousValue: _state.value);
    notify();
    await _run();
  }

  /// Clears [value]/[error] immediately, then re-runs [_call] from scratch.
  ///
  /// Prefer this when stale data shouldn't be shown at all while reloading
  /// — e.g. after changing a filter that makes the previous result invalid.
  Future<void> reload() async {
    _state = const AsyncState.loading();
    notify();
    await _run();
  }
}
