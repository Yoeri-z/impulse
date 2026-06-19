import 'package:impulse/impulse.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

abstract class CreateFn<T> {
  T call(Store store);
}

class MockCreate<T> extends Mock implements CreateFn<T> {}

abstract class FamilyCreateFn<T, R> {
  T call(Store store, R arg);
}

class MockFamilyCreate<T, R> extends Mock implements FamilyCreateFn<T, R> {}

class MockStore extends Mock implements Store {}

void main() {
  late Store store;
  late MockCreate<Object> create;

  setUpAll(() {
    registerFallbackValue(MockStore());
  });

  setUp(() {
    store = Store();
    create = MockCreate<Object>();
  });

  tearDown(() {
    store.reset();
  });

  void whenCreate() => when(() => create(any())).thenAnswer((_) => Object());
  void verifyCreateCalled(int times) =>
      verify(() => create(any())).called(times);

  group('FactoryRef', () {
    test('should not cache values and create a new instance on every get', () {
      final factoryRef = FactoryRef(create.call);
      whenCreate();

      final first = store.get(factoryRef);
      final second = store.get(factoryRef);

      expect(first, isNot(same(second)));
      verifyCreateCalled(2);
    });
  });

  group('Ref (Singleton)', () {
    test('should cache the value and return the same instance', () {
      final singletonRef = Ref(create.call);
      whenCreate();

      final first = store.get(singletonRef);
      final second = store.get(singletonRef);

      expect(first, same(second));
      verifyCreateCalled(1);
    });
  });

  group('FamilyRef', () {
    late MockFamilyCreate<Object, String> familyCreate;

    setUp(() {
      familyCreate = MockFamilyCreate<Object, String>();
    });

    void whenFamilyCreate() {
      when(() => familyCreate(any(), any())).thenAnswer((_) => Object());
    }

    test('should cache values per unique argument', () {
      final familyRef = FamilyRef<Object, String>(familyCreate.call);
      whenFamilyCreate();

      final first = store.get(familyRef('A'));
      final second = store.get(familyRef('A'));
      final third = store.get(familyRef('B'));

      expect(first, same(second));
      expect(first, isNot(same(third)));
    });

    test('should call create only once for the same argument', () {
      final familyRef = FamilyRef<Object, String>(familyCreate.call);
      whenFamilyCreate();

      store.init(familyRef('A'));
      store.init(familyRef('A'));

      verify(() => familyCreate(any(), 'A')).called(1);
    });
  });

  group('ImpulseRef tracks dependencies', () {
    late ImpulseReference ref;
    late ImpulseReference dependencyRef;

    setUp(() {
      dependencyRef = ImpulseReference(
        (store) => Object(),
        key: 'dep',
        isFactory: false,
        keepAlive: false,
        reassemble: null,
        dispose: null,
      );

      ref = ImpulseReference(
        (store) {
          store.init(dependencyRef);
          return Object();
        },
        key: 'dependency',
        isFactory: false,
        keepAlive: false,
        reassemble: null,
        dispose: null,
      );
    });

    test('reseting dependency resets dependent', () {
      final firstDependent = store.get(ref);

      store.box(dependencyRef).reset();

      final secondDependent = store.get(ref);

      expect(secondDependent, isNot(same(firstDependent)));
    });

    test('overriding (replacing) resets dependent', () {
      final firstDependent = store.get(ref);

      store.override(dependencyRef, (_) => Object());

      final secondDependent = store.get(ref);

      expect(secondDependent, isNot(same(firstDependent)));
    });

    test('removing override resets dependent', () {
      final firstDependent = store.get(ref);

      store.override(dependencyRef, (_) => Object());
      store.removeOverride(ref);

      final secondDependent = store.get(ref);

      expect(secondDependent, isNot(same(firstDependent)));
    });

    test('droping dependency resets dependent', () {
      final firstDependent = store.get(ref);

      store.drop(dependencyRef);

      final secondDependent = store.get(ref);

      expect(secondDependent, isNot(same(firstDependent)));
    });

    test('Droping dependent does not affect dependency', () {
      final firstDependency = store.get(dependencyRef);

      store.drop(ref);

      final secondDependency = store.get(dependencyRef);

      expect(secondDependency, same(firstDependency));
    });

    test('re-evaluation removes outdated dependencies from the graph', () {
      bool useDependency = true;

      final dynamicRef = ImpulseReference(
        (store) {
          if (useDependency) {
            store.init(dependencyRef);
          }
          return Object();
        },
        key: 'dynamic_dependent',
        isFactory: false,
        keepAlive: false,
        reassemble: null,
        dispose: null,
      );

      store.init(dynamicRef);

      useDependency = false;
      store.box(dynamicRef).reset();

      final firstSample = store.get(dynamicRef);
      store.box(dependencyRef).reset();
      final secondSample = store.get(dynamicRef);

      expect(secondSample, same(firstSample));
    });

    test('shared dependency stays alive until all dependents are dropped', () {
      final alternateRef = ImpulseReference(
        (store) {
          store.init(dependencyRef);
          return Object();
        },
        key: 'alternate_dependent',
        isFactory: false,
        keepAlive: false,
        reassemble: null,
        dispose: null,
      );

      store.box(ref).produce();
      store.box(ref).retain();

      store.box(alternateRef).produce();
      store.box(alternateRef).retain();

      store.drop(ref);

      expect(store.exists(dependencyRef), isTrue);

      store.drop(alternateRef);

      expect(store.exists(dependencyRef), isFalse);
    });

    test('circular dependencies are detected', () {
      late final ImpulseReference<Object> refA;
      late final ImpulseReference<Object> refB;

      refA = Ref((store) => store.get(refB));
      refB = Ref((store) => store.get(refA));

      expect(() => store.init(refA), throwsStateError);
    });

    test(
      'releasing dependent cleanly drops reference count of FamilyRef dependency',
      () {
        final familyRef = FamilyRef<Object, String>((store, arg) => Object());
        late Object createdFam;
        final dependentRef = ImpulseReference(
          (store) {
            createdFam = store.get(familyRef('A'));
            return Object();
          },
          key: 'dependent_of_family',
          isFactory: false,
          keepAlive: false,
          reassemble: null,
          dispose: null,
        );

        final depBox = store.box(dependentRef)
          ..produce()
          ..retain();
        final famBox = store.box(familyRef('A'));

        expect(createdFam, famBox.produce());
        expect(famBox.debugReferenceCount, 1);

        depBox.release();

        expect(
          store.exists(familyRef('A')),
          isFalse,
          reason:
              'The Family box should have cascaded to 0 listeners and been dropped from the store.',
        );
      },
    );
  });

  group('AsyncRef', () {
    ImpulseReference<AsyncCall>;
  });
}
