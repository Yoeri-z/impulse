import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse_signals/impulse_signals.dart';
import 'package:mocktail/mocktail.dart';

class MockNotifier with Mock implements ChangeNotifier {}

class TestController extends Controller {
  TestController() {
    signal = createSignal(0)..onDispose(() => disposeCalled = true);
  }

  bool disposeCalled = false;
  late final FlutterSignal<int> signal;

  void Function() createTestEffect() {
    return createEffect(() {
      signal.value;
    }, options: EffectOptions(onDispose: () => disposeCalled = true));
  }
}

class AllSignalsController extends Controller {
  final disposedMap = <String, bool>{};

  void init() {
    createSignal(0).onDispose(() => disposedMap['signal'] = true);
    createComputed(() => 0).onDispose(() => disposedMap['computed'] = true);
    createListSignal([]).onDispose(() => disposedMap['list'] = true);
    createSetSignal({}).onDispose(() => disposedMap['set'] = true);
    createMapSignal({}).onDispose(() => disposedMap['map'] = true);
    createQueueSignal(Queue()).onDispose(() => disposedMap['queue'] = true);
    createAsyncSignal(
      AsyncState.data(0),
    ).onDispose(() => disposedMap['async'] = true);
    createFutureSignal(
      () async => 0,
    ).onDispose(() => disposedMap['future'] = true);
    createStreamSignal(
      () => Stream.value(0),
    ).onDispose(() => disposedMap['stream'] = true);
    createComputedAsync(
      () async => 0,
    ).onDispose(() => disposedMap['computedAsync'] = true);
    createComputedFrom([
      signal(0),
    ], (args) async => 0).onDispose(() => disposedMap['computedFrom'] = true);
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

      for (final meta in signals) {
        expect(meta.signal.disposed, isFalse);
      }

      // this is necessarry because test with coverage initializes all future signals
      await Future.microtask(() async {});

      allController.dispose();

      for (final meta in signals) {
        expect(meta.signal.disposed, isTrue);
      }

      for (final entry in allController.disposedMap.entries) {
        expect(entry.value, isTrue);
      }
    });
  });

  group('attempt', () {
    test('succeeding method returns AsyncData', () async {
      final result = await attempt(() async => 'success');

      expect(result, isA<AsyncData>());
      expect(result.value, equals('success'));
    });

    test('crashing method returns AsyncError', () async {
      final exception = Exception('crash');
      final result = await attempt<String>(() async => throw exception);

      expect(result, isA<AsyncError>());
      expect(result.error, exception);
      expect(result.stackTrace, isNotNull);
    });
  });

  group('unpack', () {
    test('Unpacks AsyncLoading', () {
      final state1 = AsyncLoading();

      expect(state1.unpacked, equals((null, null)));
    });

    test('Unpacks AsyncData', () {
      final state = AsyncData(0);

      expect(state.unpacked, equals((0, null)));
    });

    test('Unpacks AsyncFailure', () {
      final state = AsyncError(0, StackTrace.empty);

      expect(state.unpacked, equals((null, state)));
    });

    test('Unpacks Future<AsyncData>', () async {
      final state = AsyncData(0);

      expect(await Future.value(state).unpacked, (0, null));
    });

    test('Unpacks Future<AsyncError>', () async {
      final state = AsyncError(0, StackTrace.empty);

      expect(await Future.value(state).unpacked, (null, state));
    });
  });

  group('Reactivity delegate', () {
    late Store store;

    setUp(() {
      store = createStore();
    });

    tearDown(() {
      store.reset();
    });

    test('excempts signals', () {
      final notifierRef = Ref((_) => signal(0));
      int notifyCount = 0;

      store.watch(notifierRef, (_) => notifyCount++);

      expect(notifyCount, 0);

      store.get(notifierRef).value++;

      expect(notifyCount, 0);
    });

    test('includes notifiers', () {
      final notifierRef = Ref((_) => ValueNotifier(0));
      int notifyCount = 0;

      store.watch(notifierRef, (_) => notifyCount++);

      expect(notifyCount, 0);

      store.get(notifierRef).value++;

      expect(notifyCount, 1);
    });

    test('Disposes signals', () {
      final sign = signal(0);
      final ref = Ref((_) => sign);

      store.init(ref);
      expect(sign.disposed, isFalse);
      store.drop(ref);
      expect(sign.disposed, isTrue);
    });

    test('Disposes Controllers', () {
      final control = TestController();
      final ref = Ref((_) => control);

      store.init(ref);
      expect(control.disposed, isFalse);
      store.drop(ref);
      expect(control.disposed, isTrue);
    });

    test('Disposes ChangeNotifiers', () {
      final notif = MockNotifier();
      final ref = Ref((_) => notif);

      store.init(ref);
      verifyNever(() => notif.dispose());
      store.drop(ref);
      verify(() => notif.dispose()).called(1);
    });
  });
}
