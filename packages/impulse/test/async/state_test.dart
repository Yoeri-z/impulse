import 'package:test/test.dart';
import 'package:impulse/impulse.dart';

void main() {
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

  group('AsyncResult.guard', () {
    test('returns AsyncData on success', () async {
      final result = await AsyncResult.guard(() async => 'success');

      expect(
        result,
        isA<AsyncData<String>>().having((r) => r.value, 'value', 'success'),
      );
    });

    test('returns AsyncFailure on error', () async {
      final exception = Exception('crash');

      final result = await AsyncResult.guard<String>(
        () async => throw exception,
      );

      expect(
        result,
        isA<AsyncFailure<String>>()
            .having((r) => r.error, 'error', exception)
            .having((r) => r.stackTrace, 'stackTrace', isNotNull),
      );
    });
  });

  group('AsyncResult.mapData', () {
    test('wraps the mapped value into AsyncData', () {
      final result = AsyncData<int>(1).mapData((value) => value + 1);

      expect(result, isA<AsyncData<int>>().having((r) => r.value, 'value', 2));
    });

    test('short-circuits an initial failure without calling onData', () {
      final exception = Exception('crash');
      var called = false;

      final result = AsyncFailure<int>(exception, StackTrace.empty)
          .mapData<int>((_) {
            called = true;
            return 0;
          });

      expect(called, isFalse);
      expect(result.error, exception);
    });
  });

  group('AsyncResult.mapDataAsync', () {
    test('chains and propagates the mapped value', () async {
      final result = await AsyncResult.guard(
        () async => 1,
      ).mapDataAsync((value) async => value + 1);

      expect(result.value, equals(2));
    });

    test('short-circuits an initial failure without calling onData', () async {
      final exception = Exception('crash');
      var called = false;

      final result = await AsyncResult.guard<int>(() async => throw exception)
          .mapDataAsync<int>((_) {
            called = true;
            return Future.value(0);
          });

      expect(called, isFalse);
      expect(result.error, exception);
    });

    test('propagates previousValue and error of the initial failure', () async {
      final exception = Exception('crash');

      final result = await AsyncFailure<int>(
        exception,
        StackTrace.empty,
        previousValue: 9,
      ).mapDataAsync<int>((_) => Future.value(0));

      expect(
        result,
        isA<AsyncFailure<int>>()
            .having((r) => r.error, 'error', exception)
            .having((r) => r.value, 'previousValue', 9),
      );
    });
  });

  group('AsyncResult.mapDataAsync with wrap', () {
    test('captures a thrown error into an AsyncFailure by default', () async {
      final exception = Exception('crash');

      final result = await AsyncResult.guard(
        () async => 1,
      ).mapDataAsync<int>((_) async => throw exception);

      expect(
        result,
        isA<AsyncFailure<int>>()
            .having((r) => r.error, 'error', exception)
            .having((r) => r.stackTrace, 'stackTrace', isNotNull),
      );
    });

    test('propagates the error when wrapping is disabled', () async {
      final exception = Exception('crash');

      await expectLater(
        AsyncResult.guard(
          () async => 1,
        ).mapDataAsync<int>((_) async => throw exception, wrap: false),
        throwsA(exception),
      );
    });

    test('captures a synchronously thrown error by default', () async {
      final exception = Exception('crash');

      final result = await AsyncResult.guard(
        () async => 1,
      ).mapDataAsync<int>((_) => throw exception);

      expect(result.error, exception);
    });

    test('extension forwards wrapping to the underlying result', () async {
      final exception = Exception('crash');

      await expectLater(
        Future<AsyncResult<int>>.value(
          AsyncData(1),
        ).mapDataAsync<int>((_) async => throw exception, wrap: false),
        throwsA(exception),
      );
    });
  });

  group('AsyncResult.recover', () {
    test('passes AsyncData through untouched', () {
      final result = AsyncData<int>(1).recover((error, st) => AsyncData(0));

      expect(result.value, equals(1));
    });

    test('repairs an AsyncFailure into AsyncData', () {
      final result = AsyncFailure<int>(
        Exception('crash'),
        StackTrace.empty,
      ).recover((error, st) => AsyncData(0));

      expect(result.value, equals(0));
    });
  });
}
