import 'dart:async';

import 'reference.dart';
import 'store.dart';

/// Runs a [callback] within a scope that retains a list of [refs].
/// The references are automatically released when the callback finishes.
Future<T> withScope<T, R>(
  FutureOr<T> Function(Store store) callback, {
  required Store store,
  required ImpulseReference<R> ref,
}) async {
  final box = store.box(ref);
  box.retain();

  try {
    return await callback(store);
  } finally {
    box.release();
  }
}
