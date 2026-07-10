import 'package:signals_flutter/signals_flutter.dart';

/// Attempts to execute the asynchronous [call] and returns its result.
///
/// Returns an [AsyncData] if the call succeeds, or an [AsyncError] if it fails.
Future<AsyncState<T>> attempt<T>(Future<T> Function() call) async {
  try {
    return AsyncData(await call());
  } catch (e, st) {
    return AsyncError(e, st);
  }
}

/// the value of an `AsyncState` unpacked into a record, usefull for linearizing the flow of async operations
/// in bodies of code.
typedef Unpacked<T> = (T? value, AsyncError<T>? err);

/// extension to add unpacking to [AsyncState]
extension UnpackAsyncState<T> on AsyncState<T> {
  /// Converts the AsyncState to an [Unpacked].
  /// Usefull for linearizing the flow of async operations in bodies of code.
  /// example
  /// ```
  /// final (value, err) = state.unpacked;
  /// ```
  Unpacked<T> get unpacked =>
      (value, this is AsyncError<T> ? this as AsyncError<T> : null);
}

/// extension to allow unpacking the future of [AsyncState]
extension UnpackFuture<T> on Future<AsyncState<T>> {
  /// Converts the AsyncState in the future to an [Unpacked].
  /// Usefull for linearizing the flow of async operations in bodies of code.
  /// example
  /// ```
  /// final (value, err) = await attempt(() => foo()).unpacked;
  /// ```
  Future<Unpacked<T>> get unpacked => then((v) => v.unpacked);
}
