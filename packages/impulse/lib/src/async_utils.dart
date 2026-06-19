import '../impulse.dart';

typedef Result<T> = (T? value, Err? err);

const emptyResult = (null, null);

Future<Result<T>> attempt<T>(Future<T> Function() call) async {
  try {
    return (await call(), null);
  } catch (e, st) {
    return (null, Err(e, st));
  }
}

class Err {
  Err(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

extension MapResult<T> on Result<T> {
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

class AsyncCall<T> extends ImpulseNotifier {
  AsyncCall(this.call) {
    _execute();
  }

  final Future<T> Function() call;

  Result<T> result = emptyResult;

  Future<void> _execute() async {
    result = await attempt(call);
    notify();
  }

  Future<void> refresh() async {
    _execute();
  }

  Future<void> reload() async {
    result = emptyResult;
    notify();
    _execute();
  }
}
