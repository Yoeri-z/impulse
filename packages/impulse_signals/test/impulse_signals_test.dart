import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:impulse_signals/impulse_signals.dart';

class TestController extends Controller {
  TestController() {
    signal = createSignal(0, dispose: (_) => disposeCalled = true);
  }

  bool disposeCalled = false;
  late final FlutterSignal<int> signal;

  void Function() createTestEffect() {
    return createEffect(() {
      signal.value;
    }, onDispose: () => disposeCalled = true);
  }
}

class AllSignalsController extends Controller {
  final disposedMap = <String, bool>{};

  void init() {
    createSignal(0, dispose: (_) => disposedMap['signal'] = true);
    createComputed(() => 0, dispose: (_) => disposedMap['computed'] = true);
    createListSignal([], dispose: (_) => disposedMap['list'] = true);
    createSetSignal({}, dispose: (_) => disposedMap['set'] = true);
    createMapSignal({}, dispose: (_) => disposedMap['map'] = true);
    createQueueSignal(Queue(), dispose: (_) => disposedMap['queue'] = true);
    createAsyncSignal(
      AsyncState.data(0),
      dispose: (_) => disposedMap['async'] = true,
    );
    createFutureSignal(
      () async => 0,
      dispose: (_) => disposedMap['future'] = true,
    );
    createStreamSignal(
      () => Stream.value(0),
      dispose: (_) => disposedMap['stream'] = true,
    );
    createComputedAsync(
      () async => 0,
      dispose: (_) => disposedMap['computedAsync'] = true,
    );
    createComputedFrom(
      [signal(0)],
      (args) async => 0,
      dispose: (_) => disposedMap['computedFrom'] = true,
    );
  }
}

void main() {
  group('Controller', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
    });

    tearDown(() {
      if (!controller.disposed) {
        controller.dispose();
      }
    });

    group('Controller.createSignal disposal', () {
      test('calls dispose callback', () {
        expect(controller.disposeCalled, isFalse);

        controller.dispose();

        expect(controller.disposeCalled, isTrue);
      });

      test('disposes a signal', () {
        expect(controller.signal.disposed, isFalse);

        controller.dispose();

        expect(controller.signal.disposed, isTrue);
        expect(controller.registeredSignals, isEmpty);
      });
    });

    group('Controller.createEffect disposal', () {
      test('calls dispose callback', () {
        controller.createTestEffect();

        expect(controller.disposeCalled, isFalse);

        controller.dispose();

        expect(controller.disposeCalled, isTrue);
        expect(controller.registeredEffects, isEmpty);
      });

      test('Cleanup removes effect', () {
        final cleanup = controller.createTestEffect();

        cleanup();

        expect(controller.disposeCalled, isTrue);
        expect(controller.registeredEffects, isEmpty);
      });
    });

    test('Controller disposal flag', () {
      expect(controller.disposed, isFalse);

      controller.dispose();

      expect(controller.disposed, isTrue);
    });

    test('disposes all variations of signals', () async {
      final allController = AllSignalsController();
      allController.init();

      final signals = allController.registeredSignals;
      expect(signals.length, 11);

      for (final meta in signals) {
        expect(meta.signal.disposed, isFalse);
      }

      allController.dispose();

      for (final meta in signals) {
        expect(meta.signal.disposed, isTrue);
      }

      expect(allController.disposedMap.length, 11);
      for (final entry in allController.disposedMap.entries) {
        expect(entry.value, isTrue);
      }
    });
  });

  group('attempt', () {
    test('returns value on success', () async {
      final result = await attempt(() async => 'success');

      expect(result.$1, 'success');
      expect(result.$2, isNull);
    });

    test('returns error on failure', () async {
      final exception = Exception('fail');
      final result = await attempt(() async => throw exception);

      expect(result.$1, isNull);
      expect(result.$2, isNotNull);
      expect(result.$2!.error, exception);
    });
  });
}
