import 'package:meta/meta.dart';

/// Attempts to execute the asynchronous [call] and returns its result.
///
/// Returns an [AsyncData] if the call succeeds, or an [AsyncFailure] if it fails.
Future<AsyncResult<T>> attempt<T>(Future<T> Function() call) async {
  try {
    return AsyncData(await call());
  } catch (e, st) {
    return AsyncFailure(e, st);
  }
}

/// Represents the result of an asynchronous operation, containing either
/// a success value or a failure error.
sealed class AsyncResult<T> {
  /// The value of the asynchronous operation, if available.
  T? get value;

  /// The error of the asynchronous operation, if available.
  Object? get error;

  /// The stack trace of the error, if available.
  StackTrace? get stackTrace;

  /// Whether the asynchronous operation has a value.
  bool get hasValue => value != null;

  /// Whether the asynchronous operation failed with an error.
  bool get hasError => error != null;
}

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
}

/// Represents a successfully completed asynchronous operation with a value.
class AsyncData<T> extends AsyncState<T> implements AsyncResult<T> {
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
}

/// Represents a failed asynchronous operation.
class AsyncFailure<T> extends AsyncState<T> implements AsyncResult<T> {
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
}
