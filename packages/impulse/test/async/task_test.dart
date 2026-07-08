import 'dart:async';
import 'package:impulse/impulse.dart';
import 'package:test/test.dart';

void main() {
  Task<int> createSuccessTask(int result) {
    return Task(() async => result);
  }

  Task<int> createDelayedTask(int result, Completer<void> gate) {
    return Task(() async {
      await gate.future;
      return result;
    });
  }

  Task<int> createErrorTask([Exception? err]) {
    final errorToThrow = err ?? Exception('Default error');
    return Task(() async => throw errorToThrow);
  }

  group('Initialization and Success State', () {
    test('starts in loading state without a value', () {
      final gate = Completer<void>();
      final task = createDelayedTask(0, gate);

      expect(task.isLoading, isTrue);
      expect(task.hasValue, isFalse);
    });

    test('resolves value and clears loading state', () async {
      final task = createSuccessTask(100);

      await Future.delayed(Duration.zero);

      expect(task.value, 100);
      expect(task.isLoading, isFalse);
    });

    test('requireValue returns data when present', () async {
      final task = createSuccessTask(100);
      await Future.delayed(Duration.zero);

      expect(task.requireValue, 100);
    });

    test('calls onSuccess callback with result', () async {
      int? capturedValue;

      final _ = Task(() async => 99, onSuccess: (val) => capturedValue = val);

      await Future.delayed(Duration.zero);
      expect(capturedValue, 99);
    });

    test('result getter returns valid tuple on success', () async {
      final task = createSuccessTask(0);
      await Future.delayed(Duration.zero);

      final (val, err) = task.result;
      expect(val, 0);
      expect(err, isNull);
    });
  });

  group('Error Handling', () {
    test('resolves error and stack trace', () async {
      final exception = Exception('Failed');
      final task = createErrorTask(exception);

      await Future.delayed(Duration.zero);

      expect(task.hasError, isTrue);
      expect(task.error, exception);
      expect(task.stackTrace, isNotNull);
    });

    test('requireValue throws when no value is present', () {
      final gate = Completer<void>();
      final task = createDelayedTask(0, gate);

      expect(() => task.requireValue, throwsA(anything));
    });

    test('calls onError callback with exception', () async {
      Object? capturedError;

      final _ = Task(
        () async => throw Exception('Crash'),
        onError: (err, st) => capturedError = err,
      );

      await Future.delayed(Duration.zero);
      expect(capturedError, isA<Exception>());
    });

    test('result getter returns Err tuple on failure', () async {
      final task = createErrorTask();
      await Future.delayed(Duration.zero);

      final (val, err) = task.result;
      expect(val, isNull);
      expect(err, isNotNull);
    });
  });

  group('refresh()', () {
    test('sets loading to true but keeps previous value', () async {
      int counter = 1;
      final task = Task(() async => counter++);
      await Future.delayed(Duration.zero);

      task.refresh();

      expect(task.isLoading, isTrue);
      expect(task.value, 1);
    });

    test('resolves to new value after completion', () async {
      int counter = 1;
      final task = Task(() async => counter++);
      await Future.delayed(Duration.zero);

      await task.refresh();

      expect(task.value, 2);
      expect(task.isLoading, isFalse);
    });
  });

  group('reload()', () {
    test('clears previous value and error immediately', () async {
      final task = createSuccessTask(0);
      await Future.delayed(Duration.zero);

      task.reload();

      expect(task.hasValue, isFalse);
      expect(task.value, isNull);
      expect(task.isLoading, isTrue);
    });

    test('resolves to new value after completion', () async {
      int counter = 1;
      final task = Task(() async => counter++);
      await Future.delayed(Duration.zero);

      await task.reload();

      expect(task.value, 2);
    });
  });

  group('Disposal', () {
    test('aborts state update if disposed during execution', () async {
      final gate = Completer<void>();
      final task = createDelayedTask(0, gate);

      task.dispose();

      gate.complete();
      await Future.delayed(Duration.zero);

      expect(task.hasValue, isFalse);
    });

    test('does not fire callbacks if disposed before completion', () async {
      bool callbackFired = false;
      final gate = Completer<void>();
      final task = Task(() async {
        await gate.future;
        return 0;
      }, onSuccess: (_) => callbackFired = true);

      task.dispose();

      gate.complete();
      await Future.delayed(Duration.zero);

      expect(callbackFired, isFalse);
    });
  });

  group('Notifier logic', () {
    test('calls notify upon state changes', () async {
      final task = createSuccessTask(0);

      int notifyCount = 0;
      task.addListener(() => notifyCount++);
      await Future.delayed(Duration.zero);
      expect(notifyCount, 1);
    });
  });

  group('Concurrency and Race Conditions', () {
    test(
      'discards result of an older run if a newer run was started',
      () async {
        final completer1 = Completer<int>();
        final completer2 = Completer<int>();
        int callCount = 0;

        final task = Task(() {
          callCount++;
          if (callCount == 1) return completer1.future;
          return completer2.future;
        });

        task.refresh();

        completer2.complete(200);
        await Future.delayed(Duration.zero);

        expect(task.value, 200, reason: 'Task should adopt the newest run');

        completer1.complete(100);
        await Future.delayed(Duration.zero);

        expect(
          task.value,
          200,
          reason: 'Task should ignore the stale result from Run 1',
        );
      },
    );

    test('does not fire callbacks for discarded runs', () async {
      final completer1 = Completer<int>();
      final completer2 = Completer<int>();
      int callCount = 0;
      int successCallbackCount = 0;

      final task = Task(() {
        callCount++;
        return callCount == 1 ? completer1.future : completer2.future;
      }, onSuccess: (_) => successCallbackCount++);

      task.refresh();

      completer1.complete(100);
      await Future.delayed(Duration.zero);

      expect(
        successCallbackCount,
        0,
        reason: 'Should not fire onSuccess for discarded run',
      );

      completer2.complete(200);

      await Future.delayed(Duration.zero);

      expect(
        successCallbackCount,
        1,
        reason: 'Should fire onSuccess for the active run',
      );
    });
  });

  group('taskRef', () {
    test('creates a Ref correctly wrapping the async call', () {
      final myRef = taskRef((store) async => 'data');

      final store = Store();
      final taskInstance = store.get(myRef);

      expect(taskInstance, isA<Task<String>>());
    });
  });
}
