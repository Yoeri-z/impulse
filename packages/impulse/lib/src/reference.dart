import 'package:meta/meta.dart';

import 'store.dart';

/// A function that creates an instance of [T] using the provided [store].
typedef Create<T> = T Function(Store store);

/// A function that handles the disposal of an instance of [T] using the provided [store].
typedef Dispose<T> = void Function(T value);

/// A function tha updates the contents of value.
typedef Update<T> = void Function(T value);

/// A function that creates an instance of [T] using the provided [store] and a parameter of type [R].
typedef FamilyCreate<T, R> = T Function(Store store, R param);

/// A function that retrieves an instance of [T].
typedef Get<T> = T Function();

/// Interface for references that dont have a key (so all of them except familyRef)
abstract class KeylessRef<T> {
  ImpulseReference<T> call();
}

/// A definition of how an object is created, identified, and managed within the store.
@immutable
class ImpulseReference<T> {
  /// Creates an [ImpulseReference].
  ImpulseReference({
    required this.key,
    required this.create,
    required this.reassemble,
    required this.isFactory,
    required this.keepAlive,
    required this.dispose,
  });

  /// The unique key used to identify this reference in the store.
  final Object key;

  /// The function used to create the object.
  final Create<T> create;

  /// The function used to update the object when the object reassembles.
  ///
  /// This usefull to ensure compatibility with hot reload.
  final Update<T>? reassemble;

  /// Whether a new instance should be created every time it is requested.
  final bool isFactory;

  /// Whether the object should remain in the store even when its reference count reaches zero.
  final bool keepAlive;

  /// An optional function to handle manual disposal of the object.
  final Dispose<T>? dispose;
}

/// A reference that creates a new instance every time it is retrieved from the store.
@immutable
class FactoryRef<T> implements KeylessRef<T> {
  /// Creates a [FactoryRef] with a [create] function and an optional [dispose] function.
  const FactoryRef(this.create, {this.reassemble, this.dispose});

  /// The function used to create the object.
  final Create<T> create;

  /// The function used to update the object when the box reassembles.
  ///
  /// This usefull to ensure compatibility with hot reload.
  final Update<T>? reassemble;

  /// An optional function to handle manual disposal of the object.
  final Dispose<T>? dispose;

  /// Get the value this [FactoryRef] refers to from the [store].
  T get(Store store) {
    final ref = call();

    return store.get(ref);
  }

  /// Returns an [ImpulseReference] representing this factory.
  @override
  ImpulseReference<T> call() {
    return ImpulseReference(
      key: this,
      create: create,
      isFactory: true,
      keepAlive: true,
      reassemble: reassemble,
      dispose: dispose,
    );
  }
}

/// A reference that creates and caches a single instance in the store.
@immutable
class Ref<T> implements KeylessRef<T> {
  /// Creates a [Ref] with a [create] function.
  const Ref(this.create, {this.reassemble, this.dispose});

  /// The function used to create the object.
  final Create<T> create;

  /// The function used to update the object when the box reassembles.
  ///
  /// This usefull to ensure compatibility with hot reload.
  final Update<T>? reassemble;

  /// An optional function to handle manual disposal of the object.
  final Dispose<T>? dispose;

  /// Get the value this [Ref] refers to from the [store].
  T get(Store store) {
    final ref = call();

    return store.get(ref);
  }

  /// Returns an [ImpulseReference] representing this singleton.
  @override
  ImpulseReference<T> call() {
    return ImpulseReference(
      key: this,
      create: create,
      isFactory: false,
      keepAlive: false,
      reassemble: reassemble,
      dispose: dispose,
    );
  }
}

/// A reference that creates and caches a single instance in the store forever (until the store gets reset).
/// Commonly this is called a singleton.
@immutable
class SingletonRef<T> implements KeylessRef<T> {
  /// Creates a [Ref] with a [create] function.
  const SingletonRef(this.create, {this.reassemble, this.dispose});

  /// The function used to create the object.
  final Create<T> create;

  /// The function used to update the object when the box reassembles.
  ///
  /// This usefull to ensure compatibility with hot reload.
  final Update<T>? reassemble;

  /// An optional function to handle manual disposal of the object.
  final Dispose<T>? dispose;

  /// Get the value this [Ref] refers to from the [store].
  T get(Store store) {
    final ref = call();

    return store.get(ref);
  }

  /// Returns an [ImpulseReference] representing this singleton.
  @override
  ImpulseReference<T> call() {
    return ImpulseReference(
      key: this,
      create: create,
      isFactory: false,
      keepAlive: true,
      reassemble: reassemble,
      dispose: dispose,
    );
  }
}

/// A reference that creates and caches unique instances based on an input parameter of type [R].
@immutable
class FamilyRef<T, R> {
  /// Creates a [FamilyRef] with a [create] function.
  const FamilyRef(this.create, {this.reassemble, this.dispose});

  /// The function used to create the object with a parameter.
  final FamilyCreate<T, R> create;

  /// The function used to update the object when the box reassembles.
  ///
  /// This usefull to ensure compatibility with hot reload.
  final Update<T>? reassemble;

  /// An optional function to handle manual disposal of the object.
  final Dispose<T>? dispose;

  /// Get the value this [FamilyRef] refers to from the [store].
  T get(Store store, R param) {
    final ref = call(param);

    return store.get(ref);
  }

  /// Returns an [ImpulseReference] representing this family member for a specific [param].
  ImpulseReference<T> call(R param) {
    return ImpulseReference(
      key: (this, param),
      create: (store) => create(store, param),
      isFactory: false,
      keepAlive: false,
      reassemble: reassemble,
      dispose: dispose,
    );
  }
}
