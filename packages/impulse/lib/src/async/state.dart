import 'package:meta/meta.dart';

/// Attempts to execute the asynchronous [call] and returns its result.
///
/// Returns an [AsyncData] if the call succeeds, or an [AsyncFailure] if it fails.
Future<AsyncState<T>> attempt<T>(Future<T> Function() call) async {
  try {
    return AsyncData(await call());
  } catch (e, st) {
    return AsyncFailure(e, st);
  }
}

/// the value of an `AsyncState` unpacked into a record, usefull for linearizing the flow of async operations
/// in bodies of code.
typedef Unpacked<T> = (T? value, AsyncFailure<T>? err);

/// extension to allow unpacking the future of a state
extension UnpackFuture<T> on Future<AsyncState<T>> {
  /// Converts the AsyncState in the future to an [Unpacked].
  /// Usefull for linearizing the flow of async operations in bodies of code.
  /// example
  /// ```
  /// final (value, err) = await attempt(() => foo()).unpacked;
  /// ```
  Future<Unpacked<T>> get unpacked => then((v) => v.unpacked);
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

  /// Wether this [AsyncState] is an [AsyncFailure]
  bool get isFailure => this is AsyncFailure<T>;

  /// Cast this [AsyncState] to [AsyncFailure]
  AsyncFailure<T> get asFailure;

  /// Unpacks the state into a record.
  /// Usefull for linearizing the flow of async operations in bodies of code.
  ///
  /// example
  /// ```
  /// final (value, err) = state.unpacked;
  ///
  /// if(err != null){
  ///   logErr(err);
  /// }
  ///
  /// print(value);
  /// ```
  Unpacked<T> get unpacked => (value, isFailure ? asFailure : null);

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
    'AsyncState is of type AsyncLoading, can not be casted to AsyncFailure',
  );
}

/// Represents a successfully completed asynchronous operation with a value.
class AsyncData<T> extends AsyncState<T> {
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
    'AsyncState is of type AsyncLoading, can not be casted to AsyncFailure',
  );
}

/// Represents a failed asynchronous operation.
class AsyncFailure<T> extends AsyncState<T> {
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
