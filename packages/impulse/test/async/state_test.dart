import 'package:test/test.dart';
import 'package:impulse/impulse.dart';

void main() {
  group('attempt', () {
    test('succeeding method returns AsyncData', () async {
      final result = await attempt(() async => 'success');

      expect(result, isA<AsyncData>());
      expect(result.value, equals('success'));
    });

    test('crashing method returns AsyncFailure captured error', () async {
      final exception = Exception('crash');
      final result = await attempt<String>(() async => throw exception);

      expect(result, isA<AsyncFailure>());
      expect(result.error, exception);
      expect(result.stackTrace, isNotNull);
    });
  });

  group('AsyncState.map', () {
    test('calls onLoading when AsyncLoading', () {
      final state = AsyncLoading(previousValue: Object());

      Object? callbackValue;

      final output = state.map(
        onData: (data) => 'DataState',
        onError: (error, stackTrace, data) => 'ErrorState',
        onLoading: (data) {
          callbackValue = data;

          return 'LoadingState';
        },
      );

      expect(callbackValue, same(state.previousValue));
      expect(output, equals('LoadingState'));
    });

    test('calls onData when AsyncData', () {
      final state = AsyncData(Object());

      Object? callbackValue;

      final output = state.map(
        onData: (data) {
          callbackValue = data;
          return 'DataState';
        },
        onError: (error, stackTrace, data) => 'ErrorState',
        onLoading: (data) => 'LoadingState',
      );

      expect(callbackValue, same(state.value));
      expect(output, equals('DataState'));
    });

    test('calls onError when AsyncFailure', () {
      final state = AsyncFailure(
        Object(),
        StackTrace.current,
        previousValue: Object(),
      );

      Object? callbackError;
      Object? callbackStacktrace;
      Object? callbackValue;

      final output = state.map(
        onData: (data) => 'DataState',
        onError: (error, stackTrace, data) {
          callbackError = error;
          callbackStacktrace = stackTrace;
          callbackValue = data;

          return 'ErrorState';
        },
        onLoading: (data) => 'LoadingState',
      );

      expect(callbackError, same(state.error));
      expect(callbackStacktrace, same(state.stackTrace));
      expect(callbackValue, same(state.value));
      expect(output, equals('ErrorState'));
    });
  });
}
