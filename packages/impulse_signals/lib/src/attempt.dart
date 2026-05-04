import 'package:signals_flutter/signals_flutter.dart';

typedef Result<T> = (T?, AsyncError<T>?);

Future<Result<T>> attempt<T>(Future<T> Function() call) async {
  try {
    return (await call(), null);
  } catch (e, st) {
    return (null, AsyncError<T>(e, st));
  }
}
