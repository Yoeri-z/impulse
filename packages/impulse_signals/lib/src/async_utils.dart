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
