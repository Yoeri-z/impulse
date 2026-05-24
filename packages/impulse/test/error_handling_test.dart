import 'package:test/test.dart';
import 'package:impulse/impulse.dart';

void main() {
  group('attempt', () {
    test('succeeding method returns value and null error', () async {
      final result = await attempt(() async => 'success');

      expect(result.$1, equals('success'));
      expect(result.$2, isNull);
    });

    test('crashing method returns null value and captured error', () async {
      final exception = Exception('crash');
      final result = await attempt<String>(() async => throw exception);

      expect(result.$1, isNull);
      expect(result.$2, isNotNull);
      expect(result.$2!.error, equals(exception));
      expect(result.$2!.stackTrace, isNotNull);
    });
  });

  group('MapResult extension on Result', () {
    test('calls onNothing when value and error are both null', () {
      const Result<String> result = (null, null);

      final output = result.map(
        onNothing: () => 'nothing',
        onValue: (val) => 'value: $val',
        onError: (err) => 'error',
      );

      expect(output, equals('nothing'));
    });

    test('calls onValue when value is non-null and error is null', () {
      final Result<String> result = ('hello', null);

      final output = result.map(
        onNothing: () => 'nothing',
        onValue: (val) => 'value: $val',
        onError: (err) => 'error',
      );

      expect(output, equals('value: hello'));
    });

    test('calls onError when value is null and error is non-null', () {
      final exception = Exception('failure');
      final Result<String> result = (null, Err(exception, StackTrace.empty));

      final output = result.map(
        onNothing: () => 'nothing',
        onValue: (val) => 'value: $val',
        onError: (err) => 'error: ${err.error}',
      );

      expect(output, equals('error: Exception: failure'));
    });

    test('calls onValueAndError when both value and error are non-null and callback is provided', () {
      final exception = Exception('both');
      final Result<String> result = ('data', Err(exception, StackTrace.empty));

      final output = result.map(
        onNothing: () => 'nothing',
        onValue: (val) => 'value: $val',
        onError: (err) => 'error',
        onValueAndError: (val, err) => 'both: $val with ${err.error}',
      );

      expect(output, equals('both: data with Exception: both'));
    });

    test('falls back to onValue when both value and error are non-null but onValueAndError is null', () {
      final exception = Exception('fallback');
      final Result<String> result = ('data', Err(exception, StackTrace.empty));

      final output = result.map(
        onNothing: () => 'nothing',
        onValue: (val) => 'value: $val',
        onError: (err) => 'error',
        onValueAndError: null,
      );

      expect(output, equals('value: data'));
    });
  });
}
