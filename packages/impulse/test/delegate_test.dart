import 'package:impulse/impulse.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAdapter extends Mock implements ReactivityAdapter {}

class MockObject {}

class MockSubscription extends Mock {
  void call();
}

class MockStore extends Mock implements Store {}

class SimpleListenable implements ImpulseListenable {
  final List<void Function()> _listeners = [];

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notify() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

class MockDisposable extends Mock implements Disposable {}

void main() {
  late ReactivityDelegate delegate;
  late MockAdapter adapter;
  late MockSubscription subscription;

  setUpAll(() {
    registerFallbackValue(MockStore());
  });

  setUp(() {
    delegate = ReactivityDelegate();
    adapter = MockAdapter();
    subscription = MockSubscription();
  });

  group('ReactivityDelegate.addAdapter', () {
    test('should trigger custom adapter onBind', () {
      final object = MockObject();
      final subCall = subscription.call;
      when(() => adapter.onBind(object, any())).thenReturn(subCall);

      delegate.addAdapter(adapter);
      final unbind = delegate.onBind(object, () {});

      expect(unbind, equals(subCall));
      verify(() => adapter.onBind(object, any())).called(1);
    });

    test('should trigger custom adapter onDispose', () {
      final object = MockObject();
      final store = Store();
      when(() => adapter.onDispose(any(), any())).thenAnswer((_) {});

      delegate.addAdapter(adapter);
      delegate.onDispose(store, object);

      verify(() => adapter.onDispose(store, object)).called(1);
    });

    test('should merge multiple unbinders', () {
      final object = MockObject();
      final adapter1 = MockAdapter();
      final adapter2 = MockAdapter();
      final sub1 = MockSubscription();
      final sub2 = MockSubscription();

      when(() => adapter1.onBind(object, any())).thenReturn(sub1.call);
      when(() => adapter2.onBind(object, any())).thenReturn(sub2.call);

      delegate.addAdapter(adapter1);
      delegate.addAdapter(adapter2);

      final unbind = delegate.onBind(object, () {});
      expect(unbind, isNotNull);
      expect(unbind, isNot(same(sub1.call)));
      expect(unbind, isNot(same(sub2.call)));

      unbind!();

      verify(() => sub1()).called(1);
      verify(() => sub2()).called(1);
    });
  });

  group('Default Adapters', () {
    test('should handle ImpulseListenable by default', () {
      final listenable = SimpleListenable();
      int count = 0;

      final unbind = delegate.onBind(listenable, () => count++);
      listenable.notify();

      expect(count, 1);
      unbind?.call();
    });

    test('should handle Disposable by default', () {
      final disposable = MockDisposable();
      final store = Store();

      delegate.onDispose(store, disposable);

      verify(() => disposable.dispose()).called(1);
    });
  });
}
