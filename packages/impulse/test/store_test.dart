import 'package:impulse/impulse.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockListenable extends Mock implements ImpulseListenable {}

class MockDisposable extends Mock implements Disposable {}

class MockObject {}

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
      final retrieved = store.get(objectRef());

      expect(retrieved, isA<MockObject>());
    });

    test('should return the same instance for singleton references', () {
      final first = store.get(objectRef());
      final second = store.get(objectRef());

      expect(first, same(second));
    });
  });

  group('Store.exists', () {
    final objectRef = Ref((store) => MockObject());

    test('should return false if the reference is not in the store', () {
      expect(store.exists(objectRef()), isFalse);
    });

    test('should return true if the reference has been get', () {
      store.init(objectRef());

      expect(store.exists(objectRef()), isTrue);
    });
  });

  group('Store.box', () {
    final objectRef = Ref((store) => MockObject());

    test('should return the same box instance for the same reference', () {
      final box1 = store.box(objectRef());
      final box2 = store.box(objectRef());

      expect(box1, same(box2));
    });
  });

  group('Store.watch', () {
    late MockListenable listenable;
    late ImpulseReference<MockListenable> listenableRef;

    setUp(() {
      listenable = MockListenable();
      listenableRef = Ref((store) => listenable)();
    });

    test('should trigger callback when the listenable notifies', () {
      int callCount = 0;
      void Function() notify = () {};

      when(() => listenable.addListener(any())).thenAnswer((invocation) {
        notify = invocation.positionalArguments.first as void Function();
      });

      store.watch(listenableRef, (_) => callCount++);

      // Bind box to listener (this calls addlistener on our ListenerMock basically)
      // watch is always lazy and doesnt return a value from the box so it doesnt actually initialize the box
      store.init(listenableRef);

      notify();

      expect(callCount, 1);
    });

    test('should trigger callback when the object is replaced', () {
      int callCount = 0;
      store.watch(listenableRef, (_) => callCount++);

      final box = store.box(listenableRef);
      box.produce(); // Initialize
      box.replace(MockListenable());

      expect(callCount, 1);
    });

    test('should stop triggering after unsubscription', () {
      int callCount = 0;
      void Function() notify = () {};

      when(() => listenable.addListener(any())).thenAnswer((invocation) {
        notify = invocation.positionalArguments.first as void Function();
      });

      final unwatch = store.watch(listenableRef, (_) => callCount++);
      store.init(listenableRef);

      unwatch();
      notify();

      expect(callCount, 0);
    });
  });

  group('Store.drop', () {
    late MockDisposable disposable;
    late ImpulseReference<MockDisposable> disposableRef;

    setUp(() {
      disposable = MockDisposable();
      disposableRef = Ref((store) => disposable)();
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
      final r1 = Ref((s) => d1)();
      final r2 = Ref((s) => d2)();

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
    )();
    final r2 = Ref(
      (s) => Object(),
      reassemble: (value) => reassembled2 = true,
    )();

    store.init(r1);
    store.init(r2);

    store.reassemble();

    expect(reassembled1, isTrue);
    expect(reassembled2, isTrue);
  });
}
