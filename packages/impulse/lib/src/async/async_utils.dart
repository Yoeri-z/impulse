import 'dart:async';

/// A the result of a process that could yield errors
///
/// Can be destructured into a record or interacted with through the [ResultExtension].
///
/// ```
/// final (value, err) = await attempt(() => foo());
///
/// if(err != null){
///   log(err);
///   return
/// }
///
/// bar(value!);
/// ```
typedef Result<T> = (T? value, Err? err);

/// An empty [Result], contains no value and no error.
///
/// Can be used to indicate a loading state.
const emptyResult = (null, null);

/// Attempt to execute a function, safely catches any errors and returns a [Result].
/// A result is a record that can be destructured or interacted with through the [ResultExtension]
///
/// **Usage example**:
/// ```
/// final (value, err) = await attempt(() => foo());
///
/// if(err != null){
///   log(err);
///   return
/// }
///
/// bar(value!);
/// ```
FutureOr<Result<T>> attempt<T>(FutureOr<T> Function() call) async {
  try {
    return (await call(), null);
  } catch (e, st) {
    return (null, Err(e, st));
  }
}

/// A wrapper for an error or exception.
///
/// Contains the thrown [Object] and the [StackTrace]
class Err {
  Err(this.error, this.stackTrace);

  /// The object that was thrown.
  final Object error;

  /// The stacktrace belonging to the throwing of [error].
  final StackTrace stackTrace;
}

/// An extension on [Result], provides functions and getters to interact with the record without destructuring.
extension ResultExtension<T> on Result<T> {
  /// The value of the process available if it succeeded.
  T? get value => $1;

  /// Wether or not this [Result] contains a value.
  bool get hasValue => value != null;

  /// The error of the process available if it failed.
  Err? get error => $2;

  /// Wether or not this [Result] contains an error.
  bool get hasError => error != null;

  /// Decleratively map the result over all possible variations.
  R map<R>({
    required R Function() onNothing,
    required R Function(T value) onValue,
    required R Function(Err err) onError,
    R Function(T value, Err err)? onValueAndError,
  }) {
    return switch (this) {
      (null, null) => onNothing(),
      (T value, Err err) when onValueAndError != null => onValueAndError(
        value,
        err,
      ),
      (T value, _) => onValue(value),
      (_, Err err) => onError(err),
    };
  }
}
