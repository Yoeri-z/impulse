import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse_flutter/impulse_flutter.dart';
import 'package:impulse_flutter/src/widgets.dart';
import 'package:mocktail/mocktail.dart';

class MockDependency extends Mock {
  void onInitialize();
  void onDispose();
}

class ListenableMock extends ChangeNotifier {
  void notify() => notifyListeners();
}

class TestApp extends StatelessWidget {
  const TestApp({super.key, this.store, required this.child});

  final Widget child;
  final Store? store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(home: child),
    );
  }
}

class RefTextBuilder<T> extends StatelessWidget {
  const RefTextBuilder({super.key, required this.ref});

  final ImpulseReference<T> ref;

  @override
  Widget build(BuildContext context) {
    return Binder(
      ref: ref,
      builder: (context, value) => Text(value.toString()),
    );
  }
}

class InitStateErrorWidget extends StatefulWidget {
  const InitStateErrorWidget({super.key, required this.ref});

  final Ref<String> ref;

  @override
  State<InitStateErrorWidget> createState() => _InitStateErrorWidgetState();
}

class _InitStateErrorWidgetState extends State<InitStateErrorWidget> {
  @override
  void initState() {
    super.initState();
    widget.ref.bind(context);
  }

  @override
  Widget build(BuildContext context) => const Text('Error');
}

void main() {
  group('Binding & Lifecycle', () {
    late MockDependency mock;
    late Ref<MockDependency> testRef;

    setUp(() {
      mock = MockDependency();
      testRef = Ref<MockDependency>((store) {
        mock.onInitialize();
        return mock;
      }, dispose: (mock) => mock.onDispose());
    });

    void verifyInitialized(int times) =>
        verify(() => mock.onInitialize()).called(times);
    void verifyDisposed(int times) =>
        verify(() => mock.onDispose()).called(times);
    void verifyNeverDisposed() => verifyNever(() => mock.onDispose());

    testWidgets('ref.bind binds and initializes object', (tester) async {
      await tester.pumpWidget(TestApp(child: RefTextBuilder(ref: testRef())));

      verifyInitialized(1);
    });

    testWidgets('object is disposed when last widget unmounts', (tester) async {
      final toggle = ValueNotifier(true);

      await tester.pumpWidget(
        TestApp(
          child: ValueListenableBuilder(
            valueListenable: toggle,
            builder: (context, show, _) {
              if (!show) return const Text('Hidden');
              return RefTextBuilder(ref: testRef());
            },
          ),
        ),
      );

      toggle.value = false;
      await tester.pumpAndSettle();

      verifyDisposed(1);
    });

    testWidgets('ref.read initializes but does NOT bind to lifecycle', (
      tester,
    ) async {
      final toggle = ValueNotifier(true);

      await tester.pumpWidget(
        TestApp(
          child: ValueListenableBuilder(
            valueListenable: toggle,
            builder: (context, show, _) {
              if (!show) return const Text('Hidden');
              return Builder(
                builder: (context) {
                  testRef.read(context);
                  return const Text('Reading');
                },
              );
            },
          ),
        ),
      );

      toggle.value = false;
      await tester.pumpAndSettle();

      verifyNeverDisposed();
    });

    testWidgets(
      'Multiple widgets sharing same ref only dispose when all unmount',
      (tester) async {
        final toggle1 = ValueNotifier(true);
        final toggle2 = ValueNotifier(true);

        await tester.pumpWidget(
          TestApp(
            child: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: toggle1,
                  builder: (context, show, _) =>
                      show ? RefTextBuilder(ref: testRef()) : const SizedBox(),
                ),
                ValueListenableBuilder(
                  valueListenable: toggle2,
                  builder: (context, show, _) =>
                      show ? RefTextBuilder(ref: testRef()) : const SizedBox(),
                ),
              ],
            ),
          ),
        );

        toggle1.value = false;
        await tester.pumpAndSettle();
        verifyNeverDisposed();

        toggle2.value = false;
        await tester.pumpAndSettle();
        verifyDisposed(1);
      },
    );
  });

  group('Reactivity', () {
    late ListenableMock listenable;
    late Ref<ListenableMock> listenableRef;

    setUp(() {
      listenable = ListenableMock();
      listenableRef = Ref((store) => listenable);
    });

    testWidgets('widget rebuilds when object notifies', (tester) async {
      int buildCount = 0;
      await tester.pumpWidget(
        TestApp(
          child: Builder(
            builder: (context) {
              buildCount++;
              listenableRef.bind(context);
              return const Text('Reactive');
            },
          ),
        ),
      );

      listenable.notify();
      await tester.pump();

      expect(buildCount, 2);
    });

    testWidgets('read does NOT cause rebuild on notify', (tester) async {
      int buildCount = 0;
      await tester.pumpWidget(
        TestApp(
          child: Builder(
            builder: (context) {
              buildCount++;
              listenableRef.read(context);
              return const Text('Passive');
            },
          ),
        ),
      );

      listenable.notify();
      await tester.pump();

      expect(buildCount, 1);
    });
  });

  group('Hierarchy & Scoping', () {
    testWidgets('Nested StoreScope provides nearest store', (tester) async {
      final rootStore = createStore();
      final leafStore = createStore();
      final stringRef = Ref((store) => 'root');

      rootStore.override(stringRef(), (_) => 'root');
      leafStore.override(stringRef(), (_) => 'leaf');

      String? retrievedValue;

      await tester.pumpWidget(
        TestApp(
          store: rootStore,
          child: StoreScope(
            store: leafStore,
            child: Builder(
              builder: (context) {
                retrievedValue = stringRef.bind(context);

                return const Text('Testing Scopes');
              },
            ),
          ),
        ),
      );

      expect(retrievedValue, 'leaf');
    });

    testWidgets('StoreScope updates store when widget property changes', (
      tester,
    ) async {
      final store1 = createStore();
      final store2 = createStore();
      final ref = Ref((s) => 'val');
      store1.override(ref(), (_) => 's1');
      store2.override(ref(), (_) => 's2');

      final storeNotifier = ValueNotifier<Store>(store1);

      await tester.pumpWidget(
        ValueListenableBuilder<Store>(
          valueListenable: storeNotifier,
          builder: (context, store, _) => TestApp(
            store: store,
            child: RefTextBuilder(ref: ref()),
          ),
        ),
      );

      expect(find.text('s1'), findsOneWidget);

      storeNotifier.value = store2;
      await tester.pumpAndSettle();

      expect(find.text('s2'), findsOneWidget);
    });

    testWidgets('StoreScope resets store on dispose', (tester) async {
      final mock = MockDependency();
      final ref = Ref((s) => mock, dispose: (m) => m.onDispose());
      final toggle = ValueNotifier(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: toggle,
            builder: (context, show, _) {
              if (!show) return const Text('Gone');
              return StoreScope(child: RefTextBuilder(ref: ref()));
            },
          ),
        ),
      );

      toggle.value = false;
      await tester.pumpAndSettle();

      verify(() => mock.onDispose()).called(1);
    });
  });

  group('Error Handling', () {
    testWidgets('throws StateError when StoreScope is missing', (tester) async {
      final ref = Ref((store) => 'test');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Text(ref.bind(context));
            },
          ),
        ),
      );

      expect(tester.takeException(), isStateError);
    });

    testWidgets('throws StateError when of() called in initState', (
      tester,
    ) async {
      final ref = Ref((store) => 'test');

      await tester.pumpWidget(TestApp(child: InitStateErrorWidget(ref: ref)));

      expect(tester.takeException(), isStateError);
    });
  });

  group('Ref variations', () {
    testWidgets('FamilyRef.bind binds correctly', (tester) async {
      final family = FamilyRef<String, int>((store, arg) => 'val-$arg');
      final store = createStore();

      await tester.pumpWidget(
        TestApp(
          store: store,
          child: RefTextBuilder(ref: family(1)),
        ),
      );

      expect(find.text('val-1'), findsOneWidget);

      await tester.pumpWidget(SizedBox());

      expect(store.exists(family(1)), isFalse);
    });

    testWidgets('FactoryRef.bind retrieves fresh value', (tester) async {
      int count = 0;
      final factory = FactoryRef((store) => ++count);
      final store = createStore();

      await tester.pumpWidget(
        TestApp(
          store: store,
          child: Column(
            children: [
              RefTextBuilder(ref: factory()),
              RefTextBuilder(ref: factory()),
            ],
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  testWidgets('Selector', (tester) async {
    int buildCount = 0;

    final ref = Ref((store) => StateMock());
    final store = createStore();

    await tester.pumpWidget(
      TestApp(
        store: store,
        child: Selector(
          ref: ref(),
          selector: (counter) => counter.count,
          builder: (context, count) {
            buildCount++;
            return Text(count.toString());
          },
        ),
      ),
    );

    ref.get(store).notify();

    await tester.pump();

    expect(buildCount, 2);

    ref.get(store).notify();

    await tester.pump();

    expect(buildCount, 2);

    ref.get(store).increment();

    await tester.pumpAndSettle();

    expect(buildCount, 3);
    expect(find.text('1'), findsOneWidget);
  });

  group('ResultSelector', () {
    testWidgets('builds nothingBuilder when result is empty', (tester) async {
      final ref = Ref((store) => ResultStateMock());
      final store = createStore();

      await tester.pumpWidget(
        TestApp(
          store: store,
          child: ResultSelector<ResultStateMock, String>(
            ref: ref(),
            selector: (state) => state.result,
            nothingBuilder: (context) => const Text('Nothing'),
            valueBuilder: (context, value) => Text('Value: $value'),
            errBuilder: (context, err) => Text('Error: ${err.error}'),
          ),
        ),
      );

      expect(find.text('Nothing'), findsOneWidget);
    });

    testWidgets('builds valueBuilder when result has a value', (tester) async {
      final ref = Ref((store) => ResultStateMock());
      final store = createStore();
      ref.get(store).setValue('hello');

      await tester.pumpWidget(
        TestApp(
          store: store,
          child: ResultSelector<ResultStateMock, String>(
            ref: ref(),
            selector: (state) => state.result,
            nothingBuilder: (context) => const Text('Nothing'),
            valueBuilder: (context, value) => Text('Value: $value'),
            errBuilder: (context, err) => Text('Error: ${err.error}'),
          ),
        ),
      );

      expect(find.text('Value: hello'), findsOneWidget);
    });

    testWidgets('builds errBuilder when result has an error', (tester) async {
      final ref = Ref((store) => ResultStateMock());
      final store = createStore();
      ref.get(store).setError('some error');

      await tester.pumpWidget(
        TestApp(
          store: store,
          child: ResultSelector<ResultStateMock, String>(
            ref: ref(),
            selector: (state) => state.result,
            nothingBuilder: (context) => const Text('Nothing'),
            valueBuilder: (context, value) => Text('Value: $value'),
            errBuilder: (context, err) => Text('Error: ${err.error}'),
          ),
        ),
      );

      expect(find.text('Error: some error'), findsOneWidget);
    });

    testWidgets('builds valueAndErrorBuilder when result has both and builder is provided', (tester) async {
      final ref = Ref((store) => ResultStateMock());
      final store = createStore();
      ref.get(store).setValueAndError('hello', 'some error');

      await tester.pumpWidget(
        TestApp(
          store: store,
          child: ResultSelector<ResultStateMock, String>(
            ref: ref(),
            selector: (state) => state.result,
            nothingBuilder: (context) => const Text('Nothing'),
            valueBuilder: (context, value) => Text('Value: $value'),
            errBuilder: (context, err) => Text('Error: ${err.error}'),
            valueAndErrorBuilder: (context, value, err) => Text('Both: $value and ${err.error}'),
          ),
        ),
      );

      expect(find.text('Both: hello and some error'), findsOneWidget);
    });
  });
}

class StateMock extends ImpulseNotifier {
  int count = 0;

  void increment() {
    count++;
    notify();
  }
}

class ResultStateMock extends ImpulseNotifier {
  Result<String> result = (null, null);

  void setNothing() {
    result = (null, null);
    notify();
  }

  void setValue(String value) {
    result = (value, null);
    notify();
  }

  void setError(Object error) {
    result = (null, Err(error, StackTrace.fromString('')));
    notify();
  }

  void setValueAndError(String value, Object error) {
    result = (value, Err(error, StackTrace.fromString('')));
    notify();
  }
}
