import 'package:impulse/impulse.dart';
import 'package:test/test.dart';

void main() {
  late ImpulseNotifier notifier;

  setUp(() {
    notifier = ImpulseNotifier();
  });

  tearDown(() {
    if (!notifier.disposed) {
      notifier.dispose();
    }
  });

  test('initial state is not disposed', () {
    expect(notifier.disposed, isFalse);
  });

  test('notifies registered listeners', () {
    var callCount = 0;
    void listener() => callCount++;

    notifier.addListener(listener);
    notifier.notify();

    expect(callCount, equals(1));
  });

  test('does not notify unsubscribed listeners', () {
    var callCount = 0;
    void listener() => callCount++;

    notifier.addListener(listener);
    notifier.removeListener(listener);
    notifier.notify();

    expect(callCount, equals(0));
  });

  test('executes listeners in insertion order', () {
    final executionOrder = <int>[];

    notifier.addListener(() => executionOrder.add(1));
    notifier.addListener(() => executionOrder.add(2));
    notifier.addListener(() => executionOrder.add(3));

    notifier.notify();

    expect(executionOrder, equals([1, 2, 3]));
  });

  test('enforces listener uniqueness', () {
    var callCount = 0;
    void listener() => callCount++;

    notifier.addListener(listener);
    notifier.addListener(listener);

    notifier.notify();

    expect(callCount, equals(1));
  });

  group('Edge Cases during notify()', () {
    test('safely handles a listener removing itself during notify()', () {
      var listener1Count = 0;
      var listener2Count = 0;

      void listener1() {
        listener1Count++;
        notifier.removeListener(listener1);
      }

      void listener2() => listener2Count++;

      notifier.addListener(listener1);
      notifier.addListener(listener2);

      notifier.notify();
      expect(listener1Count, equals(1));
      expect(listener2Count, equals(1));

      notifier.notify();
      expect(listener1Count, equals(1));
      expect(listener2Count, equals(2));
    });

    test(
      'safely handles a listener removing a subsequent listener during notify()',
      () {
        var listener1Count = 0;
        var listener2Count = 0;

        void listener2() => listener2Count++;

        void listener1() {
          listener1Count++;
          notifier.removeListener(listener2);
        }

        notifier.addListener(listener1);
        notifier.addListener(listener2);

        notifier.notify();
        expect(listener1Count, equals(1));
        expect(listener2Count, equals(0));

        notifier.notify();
        expect(listener1Count, equals(2));
        expect(listener2Count, equals(0));
      },
    );

    test('safely handles a listener adding a new listener during notify()', () {
      var listener1Count = 0;
      var listener2Count = 0;

      void listener2() => listener2Count++;

      void listener1() {
        listener1Count++;
        notifier.addListener(listener2);
      }

      notifier.addListener(listener1);

      notifier.notify();
      expect(listener1Count, equals(1));
      expect(listener2Count, equals(0));

      notifier.notify();
      expect(listener1Count, equals(2));
      expect(listener2Count, equals(1));
    });
  });

  group('dispose()', () {
    test('sets disposed flag to true and clears listeners', () {
      var callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.dispose();

      expect(notifier.disposed, isTrue);

      notifier.notify();
      expect(callCount, equals(0));
    });
  });
}
