import 'package:meta/meta.dart';

import 'store.dart';

/// A function that creates an instance of [T] using the provided [store].
typedef Create<T> = T Function(Store store);

/// A function that handles the disposal of an instance of [T] using the provided [store].
typedef Dispose<T> = void Function(T value);

/// A function that updates the contents of value.
typedef Update<T> = void Function(T value);

/// A function that creates an instance of [T] using the provided [store] and a parameter of type [R].
typedef FamilyCreate<T, R> = T Function(Store store, R param);

/// A function that retrieves an instance of [T].
typedef Get<T> = T Function();

/// A definition of how an object is created, identified, and managed within the store.
@immutable
class ImpulseReference<T> {
  /// Creates an [ImpulseReference].
  const ImpulseReference(
    this.create, {
    required this.isFactory,
    required this.keepAlive,
    this.reassemble,
    this.dispose,
    Object? key,
  }) : _key = key;

  final Object? _key;

  /// The unique key used to identify this reference in the store.
  Object get key => _key ?? this;

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
class FactoryRef<T> extends ImpulseReference<T> {
  /// Creates a [FactoryRef] with a [create] function and an optional [dispose] function.
  const FactoryRef(super.create, {super.reassemble, super.dispose})
    : super(isFactory: true, keepAlive: true);
}

/// A reference that creates and caches a single instance in the store.
@immutable
class Ref<T> extends ImpulseReference<T> {
  /// Creates a [Ref] with a [create] function.
  const Ref(super.create, {super.reassemble, super.dispose})
    : super(isFactory: false, keepAlive: false);
}

/// A reference that creates and caches a single instance in the store forever (until the store gets reset).
/// Commonly this is called a singleton.
@immutable
class SingletonRef<T> extends ImpulseReference<T> {
  /// Creates a [Ref] with a [create] function.
  const SingletonRef(super.create, {super.reassemble, super.dispose})
    : super(isFactory: false, keepAlive: true);
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

  /// Returns an [ImpulseReference] representing this family member for a specific [param].
  ImpulseReference<T> call(R param) {
    return ImpulseReference(
      (store) => create(store, param),
      key: (this, param),
      isFactory: false,
      keepAlive: false,
      reassemble: reassemble,
      dispose: dispose,
    );
  }
}
