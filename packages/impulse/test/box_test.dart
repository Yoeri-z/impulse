import 'package:impulse/impulse.dart';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockStore extends Mock implements Store {}

class MockReactivityDelegate extends Mock implements ReactivityDelegate {}

abstract class CreateFn<T> {
  T call(Store store);
}

class MockCreate<T> extends Mock implements CreateFn<T> {}

abstract class DisposeFn<T> {
  void call(T value);
}

class MockDispose<T> extends Mock implements DisposeFn<T> {}

class MockListener extends Mock {
  void call();
}

class MockSubscription extends Mock {
  void call();
}

void main() {
  late MockStore store;
  late MockReactivityDelegate delegate;
  late MockCreate<int> create;
  late MockDispose<int> dispose;
  late MockSubscription subscription;
  late ImpulseReference<int> ref;

  setUpAll(() {
    registerFallbackValue(MockStore());
    registerFallbackValue(
      ImpulseReference(
        key: 'fallback',
        create: (s) => 0,
        isFactory: false,
        keepAlive: false,
        reassemble: null,
        dispose: null,
      ),
    );
  });

  setUp(() {
    store = MockStore();
    delegate = MockReactivityDelegate();
    create = MockCreate<int>();
    dispose = MockDispose<int>();
    subscription = MockSubscription();

    when(() => delegate.onBind(any(), any())).thenReturn(subscription.call);
    when(() => delegate.onDispose(any(), any())).thenAnswer((_) {});
  });

  ImpulseBox<int> createBox({
    bool isFactory = false,
    bool keepAlive = false,
    void Function(int)? reassemble,
  }) {
    ref = ImpulseReference<int>(
      key: 'test',
      create: create.call,
      isFactory: isFactory,
      keepAlive: keepAlive,
      reassemble: reassemble,
      dispose: dispose.call,
    );
    return ImpulseBox<int>(ref: ref, store: store, delegate: delegate);
  }

  void whenCreate(int value) => when(() => create(any())).thenReturn(value);
  void verifyCreateCalled(int times) =>
      verify(() => create(any())).called(times);
  void verifyOnBind(int value) =>
      verify(() => delegate.onBind(value, any())).called(1);
  void verifyNeverOnBind() => verifyNever(() => delegate.onBind(any(), any()));
  void verifyOnDispose(int value) =>
      verify(() => delegate.onDispose(any(), value)).called(1);
  void verifyRefDispose(int value) => verify(() => dispose(value)).called(1);
  void verifySubscriptionCancelled() => verify(() => subscription()).called(1);
  void verifyDrop() => verify(() => store.drop(ref)).called(1);
  void verifyNeverDrop() => verifyNever(() => store.drop(any()));

  group('Reference Counting', () {
    test('should drop from store when reference count reaches zero', () {
      final box = createBox();

      box.retain();
      box.release();

      verifyDrop();
    });

    test('should not drop if keepAlive=true', () {
      final box = createBox(keepAlive: true);

      box.retain();
      box.release();

      verifyNeverDrop();
    });

    test('should not drop if count is still above zero', () {
      final box = createBox();

      box.retain();
      box.retain();
      box.release();

      verifyNeverDrop();
    });
  });

  group('Value Production (Singleton)', () {
    test('should initialize value on first produce', () {
      final box = createBox();
      whenCreate(10);

      final value = box.produce();

      expect(value, 10);
      verifyOnBind(10);
    });

    test('should return cached value on subsequent calls', () {
      final box = createBox();
      whenCreate(10);

      box.produce();
      final value = box.produce();

      expect(value, 10);
      verifyCreateCalled(1);
    });

    test('using box after disposing throws error', () {
      final box = createBox();
      whenCreate(10);

      box.produce();
      box.dispose();

      expect(() => box.produce(), throwsStateError);
    });
  });

  group('Value Production (Factory)', () {
    test('should call create on every produce', () {
      final box = createBox(isFactory: true);
      whenCreate(10);

      box.produce();
      box.produce();

      verifyCreateCalled(2);
    });

    test('should never bind factory values', () {
      final box = createBox(isFactory: true);
      whenCreate(10);

      box.produce();

      verifyNeverOnBind();
    });
  });

  group('Replacement', () {
    test('should dispose old value and bind new value', () {
      final box = createBox();
      whenCreate(10);
      box.produce(); // initial value

      box.replace(20);

      verifyOnDispose(10);
      verifyOnBind(20);
    });

    test('should cancel previous subscription on replacement', () {
      final box = createBox();
      whenCreate(10);
      box.produce();

      box.replace(20);

      verifySubscriptionCancelled();
    });

    test('should notify listeners on replacement', () {
      final box = createBox();
      final listener = MockListener();
      box.addListener(listener.call);

      box.replace(20);

      verify(() => listener()).called(1);
    });
  });

  group('Lifecycle', () {
    test('should cancel subscription and dispose value on dispose', () {
      final box = createBox();
      whenCreate(10);
      box.produce();

      box.dispose();

      verifySubscriptionCancelled();
      verifyOnDispose(10);
    });

    test('should call reference-level dispose', () {
      final box = createBox();
      whenCreate(10);
      box.produce();

      box.dispose();

      verifyRefDispose(10);
    });

    test('should mark as disposed', () {
      final box = createBox();

      box.dispose();

      expect(box.disposed, isTrue);
    });
  });

  group('Notification', () {
    test('should manage listeners correctly', () {
      final box = createBox();
      final listener = MockListener();

      box.addListener(listener.call);
      box.notify();
      box.removeListener(listener.call);
      box.notify();

      verify(() => listener()).called(1);
    });
  });

  group('Overrides', () {
    test('overrideWith replaces ref constructor', () {
      final box = createBox();

      whenCreate(10);

      final first = box.produce();

      box.overrideWith((_) => 20);

      final second = box.produce();

      expect(first, 10);
      expect(second, 20);
    });

    test('removeOverride removes active override', () {
      final box = createBox();

      whenCreate(10);

      final first = box.produce();

      box.overrideWith((_) => 20);

      box.removeOverride();

      final second = box.produce();

      expect(first, second);
    });
  });

  test('Reassemble does nothing when value is null', () {
    final box = createBox();

    box.reassemble();

    expect(box.debugInternalValue, isNull);
  });

  test('Reassemble runs when value is non null', () {
    bool reassembled = false;
    final box = createBox(reassemble: (p0) => reassembled = true);

    whenCreate(10);

    box.produce();

    box.reassemble();

    expect(reassembled, isTrue);
  });
}
