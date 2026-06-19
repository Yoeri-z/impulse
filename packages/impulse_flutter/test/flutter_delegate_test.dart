import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse_flutter/impulse_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockChangeNotifier extends Mock implements ChangeNotifier {}

class MockListenable extends Mock implements Listenable {}

void main() {
  late Store store;

  setUp(() {
    store = Store(delegate: FlutterReactivityDelegate());
  });

  tearDown(() {
    store.reset();
  });

  void verifyDisposeCalled(MockChangeNotifier notifier) {
    verify(() => notifier.dispose()).called(1);
  }

  void verifyNeverDisposed(MockChangeNotifier notifier) {
    verifyNever(() => notifier.dispose());
  }

  void verifyAddListener(MockListenable listenable) {
    verify(() => listenable.addListener(any())).called(1);
  }

  void verifyRemoveListener(MockListenable listenable) {
    verify(() => listenable.removeListener(any())).called(1);
  }

  ImpulseReference<T> createRef<T>(T obj) {
    return Ref((store) => obj);
  }

  group('FlutterReactivityDelegate', () {
    test('ChangeNotifier gets disposed when dropped', () {
      final notifier = MockChangeNotifier();
      final ref = createRef(notifier);

      store.init(ref);
      store.drop(ref);

      verifyDisposeCalled(notifier);
    });

    test('ChangeNotifier is NOT disposed if not dropped', () {
      final notifier = MockChangeNotifier();
      final ref = createRef(notifier);

      store.init(ref);

      verifyNeverDisposed(notifier);
    });

    test('Listenable gets listener added when bound', () {
      final listenable = MockListenable();
      final ref = createRef(listenable);

      store.init(ref);

      verifyAddListener(listenable);
    });

    test('Listenable gets listener removed when dropped', () {
      final listenable = MockListenable();
      final ref = createRef(listenable);

      store.init(ref);
      store.drop(ref);

      verifyRemoveListener(listenable);
    });
  });
}
