import 'package:meta/meta.dart';

/// Represents the state of an asynchronous operation.
@immutable
sealed class AsyncState<T> {
  /// Creates a new [AsyncState] instance.
  const AsyncState();

  /// Creates an [AsyncState] in the loading state, optionally with a [previousValue].
  const factory AsyncState.loading({T? previousValue}) = AsyncLoading<T>;

  /// Creates an [AsyncState] in the success state with the given [value].
  const factory AsyncState.data(T value) = AsyncData<T>;

  /// Creates an [AsyncState] in the failure state with the given [error],
  /// [stackTrace], and optionally a [previousValue].
  const factory AsyncState.error(
    Object error,
    StackTrace stackTrace, {
    T? previousValue,
  }) = AsyncFailure<T>;

  /// The value of the asynchronous operation, if available.
  T? get value;

  /// The error of the asynchronous operation, if available.
  Object? get error;

  /// The stack trace of the error, if available.
  StackTrace? get stackTrace;

  /// Whether the asynchronous operation is currently loading.
  bool get isLoading;

  /// Whether the asynchronous operation has a value.
  bool get hasValue => value != null;

  /// Whether the asynchronous operation failed with an error.
  bool get hasError => error != null;

  /// Whether this [AsyncState] is an [AsyncFailure]
  bool get isFailure => this is AsyncFailure<T>;

  /// Cast this [AsyncState] to [AsyncFailure]
  AsyncFailure<T> get asFailure;

  /// Applies a callback based on the state's error, passed together with the
  /// previous data value (if any). See [map] for the exhaustive variant.
  /// Usefull for logging failures without breaking the flow.
  void onFailure(
    void Function(Object error, StackTrace stackTrace, T? data) action,
  ) {
    switch (this) {
      case AsyncFailure(:final error, :final stackTrace, :final previousValue):
        action(error, stackTrace, previousValue);
      case _:
        break;
    }
  }

  /// Maps the current state to a value of type [R] using the matching callback.
  R map<R>({
    required R Function(T data) onData,
    required R Function(Object error, StackTrace stackTrace, T? data) onError,
    required R Function(T? data) onLoading,
  }) {
    return switch (this) {
      AsyncData(:var value) => onData(value),
      AsyncFailure(:var error, :var stackTrace, :var previousValue) => onError(
        error,
        stackTrace,
        previousValue,
      ),
      AsyncLoading(:var previousValue) => onLoading(previousValue),
    };
  }
}

/// Represents an asynchronous operation that is currently loading.
class AsyncLoading<T> extends AsyncState<T> {
  /// Creates an [AsyncLoading] state, optionally with a [previousValue].
  const AsyncLoading({this.previousValue});

  /// The value from a previous state, if any.
  final T? previousValue;

  @override
  bool get isLoading => true;

  @override
  T? get value => previousValue;

  @override
  Object? get error => null;

  @override
  StackTrace? get stackTrace => null;

  @override
  AsyncFailure<T> get asFailure => throw StateError(
    'AsyncState is of type AsyncLoading, cannot be cast to AsyncFailure',
  );
}

/// A resolved [AsyncState]: either an [AsyncData] or an [AsyncFailure].
///
/// The loading state is not part of [AsyncResult], making it the data-side
/// flavor of [AsyncState]: one-off calls where only success or failure
/// matters, without loading UI concerns.
@immutable
sealed class AsyncResult<T> extends AsyncState<T> {
  /// Creates an [AsyncResult].
  const AsyncResult();

  /// Runs the asynchronous [call], capturing any thrown error into an
  /// [AsyncFailure] and its return value into an [AsyncData].
  static Future<AsyncResult<T>> guard<T>(Future<T> Function() call) async {
    try {
      return AsyncData(await call());
    } catch (error, stackTrace) {
      return AsyncFailure(error, stackTrace);
    }
  }

  /// Maps the result to a value of type [R] using the matching callback.
  ///
  /// This is the two-way (success or failure) exhaustive variant of
  /// [AsyncState.map], which also handles loading.
  R fold<R>({
    required R Function(T data) onData,
    required R Function(Object error, StackTrace stackTrace) onError,
  }) {
    return switch (this) {
      AsyncData(:final value) => onData(value),
      AsyncFailure(:final error, :final stackTrace) => onError(
        error,
        stackTrace,
      ),
    };
  }

  /// Chains a fallible operation onto the result.
  ///
  /// If this is an [AsyncData], runs [onData] with the value, wrapping it in
  /// an [AsyncData]. If this is an [AsyncFailure], [onData] is not called and
  /// this [AsyncFailure] is propagated unchanged. This makes it easy to
  /// sequence fallible operations without nesting or losing the error path.
  ///
  /// example
  /// ```dart
  /// final result = AsyncData(1).mapData((value) => value + 1);
  /// ```
  AsyncResult<R> mapData<R>(R Function(T data) onData) {
    return switch (this) {
      AsyncData(:final value) => AsyncData(onData(value)),
      AsyncFailure(:final error, :final stackTrace, :final previousValue) =>
        AsyncFailure<R>(
          error,
          stackTrace,
          previousValue: (previousValue as Object?) as R?,
        ),
    };
  }

  /// Chains an asynchronous fallible operation onto the result.
  ///
  /// Same as [mapData], but for operations that require awaiting.
  ///
  /// The chained call is wrapped in [AsyncResult.guard] by default, so a
  /// thrown error becomes an [AsyncFailure] instead of escaping. Set [wrap]
  /// to `false` to disable this, letting errors propagate uncaught.
  ///
  /// example
  /// ```dart
  /// final result = await AsyncResult.guard(() => fetchUser(id)).mapDataAsync(
  ///   (user) => fetchProfile(user),
  /// );
  /// ```
  Future<AsyncResult<R>> mapDataAsync<R>(
    Future<R> Function(T data) onData, {
    bool wrap = true,
  }) async {
    return switch (this) {
      AsyncData(:final value) =>
        wrap ? .guard(() => onData(value)) : AsyncData(await onData(value)),
      AsyncFailure(:final error, :final stackTrace, :final previousValue) =>
        Future.value(
          AsyncFailure<R>(
            error,
            stackTrace,
            previousValue: (previousValue as Object?) as R?,
          ),
        ),
    };
  }

  /// Repairs an [AsyncFailure] into an [AsyncData] by running [onError] with
  /// the error and stack trace. An [AsyncData] is passed through untouched.
  ///
  /// example
  /// ```dart
  /// final result = (await AsyncResult.guard(() => fetchUser(id)))
  ///     .recover((error, st) => User.guest);
  /// ```
  AsyncResult<T> recover(
    AsyncResult<T> Function(Object error, StackTrace stackTrace) onError,
  ) {
    return switch (this) {
      AsyncData<T>() => this as AsyncData<T>,
      AsyncFailure(:final error, :final stackTrace) => onError(
        error,
        stackTrace,
      ),
    };
  }
}

/// extension to chain and repair results that are still in flight.
extension AsyncResultFuture<T> on Future<AsyncResult<T>> {
  /// Chained variant of [AsyncResult.mapDataAsync] for futures of results.
  ///
  /// The chained call is wrapped in [AsyncResult.guard] by default; see
  /// [AsyncResult.mapDataAsync] for details.
  Future<AsyncResult<R>> mapDataAsync<R>(
    Future<R> Function(T data) onData, {
    bool wrap = true,
  }) {
    return then((result) => result.mapDataAsync(onData, wrap: wrap));
  }
}

/// Represents a successfully completed asynchronous operation with a value.
class AsyncData<T> extends AsyncResult<T> {
  /// Creates an [AsyncData] state with the given [value].
  const AsyncData(this.value);

  @override
  final T value;

  @override
  bool get isLoading => false;

  @override
  Object? get error => null;

  @override
  StackTrace? get stackTrace => null;

  @override
  AsyncFailure<T> get asFailure => throw StateError(
    'AsyncState is of type AsyncData, cannot be cast to AsyncFailure',
  );
}

/// Represents a failed asynchronous operation.
class AsyncFailure<T> extends AsyncResult<T> {
  /// Creates an [AsyncFailure] state with the given [error], [stackTrace], and
  /// optionally a [previousValue].
  const AsyncFailure(this.error, this.stackTrace, {this.previousValue});

  @override
  final Object error;

  @override
  final StackTrace stackTrace;

  /// The value from a previous state, if any.
  final T? previousValue;

  @override
  bool get isLoading => false;

  @override
  T? get value => previousValue;

  @override
  AsyncFailure<T> get asFailure => this;
}
