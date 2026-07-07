import 'package:signals_flutter/signals_flutter.dart';

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
typedef Result<T> = (T?, AsyncError<T>?);

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
Future<Result<T>> attempt<T>(Future<T> Function() call) async {
  try {
    return (await call(), null);
  } catch (e, st) {
    return (null, AsyncError<T>(e, st));
  }
}

extension ResultExtension<T> on Result<T> {
  /// The value of the process available if it succeeded.
  T? get value => $1;

  /// Wether or not this [Result] contains a value.
  bool get hasValue => value != null;

  /// The error of the process available if it failed.
  AsyncError<T>? get error => $2;

  /// Wether or not this [Result] contains an error.
  bool get hasError => error != null;

  /// Decleratively map the result over all possible variations.
  R map<R>({
    required R Function() onNothing,
    required R Function(T value) onValue,
    required R Function(AsyncError err) onError,
    R Function(T value, AsyncError err)? onValueAndError,
  }) {
    return switch (this) {
      (null, null) => onNothing(),
      (T value, AsyncError err) when onValueAndError != null => onValueAndError(
        value,
        err,
      ),
      (T value, _) => onValue(value),
      (_, AsyncError err) => onError(err),
    };
  }
}
