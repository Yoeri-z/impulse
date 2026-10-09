import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse_flutter/impulse_flutter.dart';

class TestDisposable implements Disposable {
  bool disposed = false;

  @override
  void dispose() => disposed = true;
}

class TestPlain {
  TestPlain(this.store);

  final Store store;
}

void main() {
  group('Disposables', () {
    testWidgets('disposes Disposable managed objects when the state is disposed', (
      tester,
    ) async {
      late DisposablesHarnessState state;

      await tester.pumpWidget(_Harness(onInitState: (s) => state = s));

      final obj = state.managed((store) => TestDisposable());

      expect(obj.disposed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(obj.disposed, isTrue);
    });

    testWidgets('invokes a custom dispose callback instead of the reactivity system', (
      tester,
    ) async {
      late DisposablesHarnessState state;
      final disposed = <TestPlain>[];

      await tester.pumpWidget(_Harness(onInitState: (s) => state = s));

      final obj = state.managed((store) => TestPlain(store), dispose: disposed.add);

      expect(disposed, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(disposed, equals([obj]));
    });

    testWidgets('passes the store of the enclosing scope to create', (tester) async {
      late DisposablesHarnessState state;

      final scopeStore = createStore();

      await tester.pumpWidget(
        _Harness(store: scopeStore, onInitState: (s) => state = s),
      );

      final obj = state.managed((store) => TestPlain(store));

      expect(obj.store, same(scopeStore));
    });

    testWidgets('recreates the object on reassemble when recreateOnReassemble is true', (
      tester,
    ) async {
      late DisposablesHarnessState state;

      await tester.pumpWidget(_Harness(onInitState: (s) => state = s));

      TestDisposable? recreated;

      final original = state.managed(
        (store) => TestDisposable(),
        reassemble: (TestDisposable obj) => recreated = obj,
        recreateOnReassemble: true,
      );

      state.reassemble();

      expect(original.disposed, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(recreated!.disposed, isTrue);
    });

    testWidgets('runs reassemble callbacks on every reassemble', (tester) async {
      final reassembled = <Object>[];
      late DisposablesHarnessState state;

      await tester.pumpWidget(_Harness(onInitState: (s) => state = s));

      final obj = state.managed(
        (store) => TestPlain(store),
        reassemble: reassembled.add,
      );

      expect(reassembled, isEmpty);

      state.reassemble();
      state.reassemble();

      expect(reassembled, equals([obj, obj]));
    });
  });
}

class DisposablesHarness extends StatefulWidget {
  const DisposablesHarness({super.key, this.onInitState});

  final void Function(DisposablesHarnessState state)? onInitState;

  @override
  DisposablesHarnessState createState() => DisposablesHarnessState();
}

class DisposablesHarnessState extends State<DisposablesHarness>
    with Disposables {
  late final Store managedStore = StoreScope.of(context, depend: false);

  @override
  void initState() {
    super.initState();
    widget.onInitState?.call(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Harness extends StatelessWidget {
  const _Harness({this.store, this.onInitState});

  final Store? store;
  final void Function(DisposablesHarnessState state)? onInitState;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: DisposablesHarness(onInitState: onInitState),
    );
  }
}
