import 'package:impulse/impulse.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockListenable extends Mock implements ImpulseListenable {}

class MockDisposable extends Mock implements Disposable {}

class MockObject {}

class MockNotifier extends ImpulseNotifier {
  int count = 0;

  void increment() {
    count++;
    notify();
  }
}

void main() {
  late Store store;

  setUpAll(() {
    registerFallbackValue(() {});
  });

  setUp(() {
    store = Store();
  });

  tearDown(() {
    store.reset();
  });

  void verifyDispose(MockDisposable disposable) {
    verify(() => disposable.dispose()).called(1);
  }

  group('Store.get', () {
    final objectRef = Ref((store) => MockObject());

    test('should retrieve the object created by the reference', () {
      final retrieved = store.get(objectRef);

      expect(retrieved, isA<MockObject>());
    });

    test('should return the same instance for singleton references', () {
      final first = store.get(objectRef);
      final second = store.get(objectRef);

      expect(first, same(second));
    });
  });

  group('Store.exists', () {
    final objectRef = Ref((store) => MockObject());

    test('should return false if the reference is not in the store', () {
      expect(store.exists(objectRef), isFalse);
    });

    test('should return true if the reference has been get', () {
      store.init(objectRef);

      expect(store.exists(objectRef), isTrue);
    });
  });

  group('Store.box', () {
    final objectRef = Ref((store) => MockObject());

    test('should return the same box instance for the same reference', () {
      final box1 = store.box(objectRef);
      final box2 = store.box(objectRef);

      expect(box1, same(box2));
    });
  });

  group('Store.watch & Store.select', () {
    late MockNotifier counter;
    late ImpulseReference<MockNotifier> counterRef;

    setUp(() {
      counter = MockNotifier();
      counterRef = Ref((store) => counter);
    });

    test('should trigger callback when the listenable notifies', () {
      int callCount = 0;

      store.watch(counterRef, (_) => callCount++);

      // Bind box to listener (this calls addlistener on our ListenerMock basically)
      // watch is always lazy and doesnt return a value from the box so it doesnt actually initialize the box
      store.init(counterRef);

      counter.notify();

      expect(callCount, 1);
    });

    test('should trigger callback when the object is replaced', () {
      int callCount = 0;
      store.watch(counterRef, (_) => callCount++);

      final box = store.box(counterRef);
      box.produce(); // Initialize
      box.replace(MockNotifier());

      expect(callCount, 1);
    });

    test('should stop triggering after unsubscription', () {
      int callCount = 0;

      final unwatch = store.watch(counterRef, (_) => callCount++);
      store.init(counterRef);

      unwatch();
      counter.notify();

      expect(callCount, 0);
      expect(store.exists(counterRef), isFalse);
    });

    test('Select notifies if value changes', () {
      int callCount = 0;

      final _ = store.select(
        counterRef,
        (counter) => counter.count,
        (_) => callCount++,
      );

      store.init(counterRef);

      counter.increment();
      counter.increment();

      expect(callCount, 2);
    });

    test('Select doesnt notify if value doesnt change', () {
      int callCount = 0;

      final _ = store.select(
        counterRef,
        (counter) => counter.count,
        (_) => callCount++,
      );

      store.init(counterRef);

      // the first notification always runs select because it has not cached an old value yet.
      counter.notify();
      counter.notify();

      expect(callCount, 1);
    });
  });

  group('Store.drop', () {
    late MockDisposable disposable;
    late ImpulseReference<MockDisposable> disposableRef;

    setUp(() {
      disposable = MockDisposable();
      disposableRef = Ref((store) => disposable);
    });

    test('should remove the object from the store', () {
      store.init(disposableRef);
      store.drop(disposableRef);

      expect(store.exists(disposableRef), isFalse);
    });

    test('should dispose the object if it implements Disposable', () {
      store.init(disposableRef);
      store.drop(disposableRef);

      verifyDispose(disposable);
    });
  });

  group('Store.reset', () {
    test('should clear all objects and dispose them', () {
      final d1 = MockDisposable();
      final d2 = MockDisposable();
      final r1 = Ref((s) => d1);
      final r2 = Ref((s) => d2);

      store.init(r1);
      store.init(r2);

      store.reset();

      expect(store.exists(r1), isFalse);
      expect(store.exists(r2), isFalse);
      verifyDispose(d1);
      verifyDispose(d2);
    });
  });

  test('Store.reassemble reassembles every ref', () {
    var reassembled1 = false;
    var reassembled2 = false;

    final r1 = Ref(
      (s) => Object(),
      reassemble: (value) => reassembled1 = true,
    );
    final r2 = Ref(
      (s) => Object(),
      reassemble: (value) => reassembled2 = true,
    );

    store.init(r1);
    store.init(r2);

    store.reassemble();

    expect(reassembled1, isTrue);
    expect(reassembled2, isTrue);
  });
}
