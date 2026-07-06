import 'dart:async';
import 'package:impulse/impulse.dart';
import 'package:test/test.dart';

void main() {
  StreamTask<int> createSuccessTask(int result) {
    return StreamTask(() => Stream.value(result));
  }

  StreamTask<int> createDelayedTask(int result, Completer<void> gate) {
    return StreamTask(() => Stream.fromFuture(gate.future.then((_) => result)));
  }

  StreamTask<int> createErrorTask([Exception? err]) {
    final errorToThrow = err ?? Exception('Default error');
    return StreamTask(() => Stream<int>.error(errorToThrow));
  }

  group('Initialization and Data State', () {
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

    test('calls onData callback with each event', () async {
      int? capturedValue;

      final _ = StreamTask(
        () => Stream.value(99),
        onData: (val) => capturedValue = val,
      );

      await Future.delayed(Duration.zero);
      expect(capturedValue, 99);
    });

    test('result getter returns valid tuple on success', () async {
      final task = createSuccessTask(0);
      await Future.delayed(Duration.zero);

      final (val, err) = task.asResult;
      expect(val, 0);
      expect(err, isNull);
    });

    test('updates value again on a second emitted event', () async {
      final controller = StreamController<int>();
      final task = StreamTask(() => controller.stream);

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(task.value, 1);

      controller.add(2);
      await Future.delayed(Duration.zero);
      expect(task.value, 2);

      await controller.close();
    });

    test('marks isDone once the stream closes', () async {
      final controller = StreamController<int>();
      final task = StreamTask(() => controller.stream);

      expect(task.isDone, isFalse);

      await controller.close();
      await Future.delayed(Duration.zero);

      expect(task.isDone, isTrue);
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

      final _ = StreamTask(
        () => Stream<int>.error(Exception('Crash')),
        onError: (err, st) => capturedError = err,
      );

      await Future.delayed(Duration.zero);
      expect(capturedError, isA<Exception>());
    });

    test('result getter returns Err tuple on failure', () async {
      final task = createErrorTask();
      await Future.delayed(Duration.zero);

      final (val, err) = task.asResult;
      expect(val, isNull);
      expect(err, isNotNull);
    });

    test('a later data event clears a previous error', () async {
      final controller = StreamController<int>();
      final task = StreamTask(() => controller.stream);

      controller.addError(Exception('oops'));
      await Future.delayed(Duration.zero);
      expect(task.hasError, isTrue);

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(task.hasError, isFalse);
      expect(task.value, 1);

      await controller.close();
    });
  });

  group('refresh()', () {
    test('sets loading to true but keeps previous value', () async {
      int counter = 1;
      final task = StreamTask(() => Stream.value(counter++));

      await Future.delayed(Duration.zero);
      task.refresh();

      expect(task.isLoading, isTrue);
      expect(task.value, 1);
    });

    test('resolves to new value after completion', () async {
      int counter = 1;
      final task = StreamTask(() => Stream.value(counter++));

      await Future.delayed(Duration.zero);
      task.refresh();
      await Future.delayed(Duration.zero);

      expect(task.value, 2);
      expect(task.isLoading, isFalse);
    });

    test(
      'cancels the previous subscription so it stops updating state',
      () async {
        final controller1 = StreamController<int>();
        final controllers = [controller1, StreamController<int>()];
        int callCount = 0;

        final task = StreamTask(() => controllers[callCount++].stream);
        await Future.delayed(Duration.zero);

        task.refresh();
        await Future.delayed(Duration.zero);

        // The old controller is no longer subscribed to; emitting on it
        // should not affect task state.
        controller1.add(999);
        await Future.delayed(Duration.zero);

        expect(task.value, isNot(999));

        await controllers[0].close();
        await controllers[1].close();
      },
    );
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
      final task = StreamTask(() => Stream.value(counter++));

      await Future.delayed(Duration.zero);
      task.reload();
      await Future.delayed(Duration.zero);

      expect(task.value, 2);
    });

    test('resets isDone so a closed stream can be re-observed', () async {
      var controller = StreamController<int>();
      final task = StreamTask(() => controller.stream);

      await controller.close();
      await Future.delayed(.zero);

      expect(task.isDone, isTrue);

      controller = StreamController<int>();

      task.reload();

      await Future.delayed(.zero);

      expect(task.isDone, isFalse);

      await controller.close();
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
      final task = StreamTask(
        () => Stream.fromFuture(gate.future.then((_) => 0)),
        onData: (_) => callbackFired = true,
      );

      task.dispose();

      gate.complete();
      await Future.delayed(Duration.zero);

      expect(callbackFired, isFalse);
    });

    test('cancels the underlying subscription', () async {
      final controller = StreamController<int>();
      final task = StreamTask(() => controller.stream);

      task.dispose();
      await Future.delayed(Duration.zero);

      expect(controller.hasListener, isFalse);

      await controller.close();
    });
  });

  group('Notifier logic', () {
    test('calls notify upon state changes', () async {
      final task = createSuccessTask(0);

      int notifyCount = 0;
      task.addListener(() => notifyCount++);
      await Future.delayed(Duration.zero);

      expect(notifyCount, 2);
    });

    test('calls notify again for each subsequent event', () async {
      final controller = StreamController<int>();
      final task = StreamTask(() => controller.stream);

      int notifyCount = 0;
      task.addListener(() => notifyCount++);

      controller.add(1);
      await Future.delayed(Duration.zero);
      controller.add(2);
      await Future.delayed(Duration.zero);

      expect(notifyCount, 2);

      await controller.close();
    });
  });

  group('Concurrency and Race Conditions', () {
    test(
      'discards result of an older run if a newer run was started',
      () async {
        final completer1 = Completer<int>();
        final completer2 = Completer<int>();
        int callCount = 0;

        final task = StreamTask(() {
          callCount++;
          final completer = callCount == 1 ? completer1 : completer2;
          return Stream.fromFuture(completer.future);
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
      int dataCallbackCount = 0;

      final task = StreamTask(() {
        callCount++;
        final completer = callCount == 1 ? completer1 : completer2;
        return Stream.fromFuture(completer.future);
      }, onData: (_) => dataCallbackCount++);

      task.refresh();

      completer1.complete(100);
      await Future.delayed(Duration.zero);

      expect(
        dataCallbackCount,
        0,
        reason: 'Should not fire onData for discarded run',
      );

      completer2.complete(200);

      await Future.delayed(Duration.zero);

      expect(
        dataCallbackCount,
        1,
        reason: 'Should fire onData for the active run',
      );
    });
  });

  group('streamTaskRef', () {
    test('creates a Ref correctly wrapping the stream', () {
      final myRef = streamRef((store) => Stream.value('data'));

      final store = Store();
      final taskInstance = store.get(myRef);

      expect(taskInstance, isA<StreamTask<String>>());
    });
  });
}
