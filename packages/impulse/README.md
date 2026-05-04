# Impulse

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg?flag=impulse)](https://codecov.io/gh/Yoeri-z/impulse)

Easy and simple state management solution that mainly functions as a dependency injection service and integrates well with other state management solutions.

Impulse provides a lightweight way to manage shared state and dependencies using a central `Store` and type-safe `References`.

> The package is currently being implemented in some production-level code to validate its real-world use. It will hit `1.0` after this is complete.

## Features

- **Type-safe Dependency Injection:** Define your objects and their dependencies using various reference types.
- **Singleton & Factory Support:** Cache objects globally or create fresh instances every time.
- **Parameterized Dependencies:** Use `FamilyRef` to create dependencies based on external arguments.
- **Reactivity Integration:** Built-in support for `Listenable` objects and custom reactivity delegates.
- **Lifecycle Management:** Automatic disposal of `Disposable` objects and custom disposal logic.

## Getting Started

Add `impulse` to your `pubspec.yaml`:

```yaml
dependencies:
  impulse: latest
```

## Core Concepts

### 1. The Store

The `Store` is the central container for all your state objects. You can use the global `$store` or create your own instances.

```dart
import 'package:impulse/impulse.dart';

// Use the global store
$store

// Or create your own
final myStore = Store();
```

> I prefer to prefix anything related to global state with `$`.

### 2. References

References define _how_ an object is created.

#### `Ref<T>` (Singleton)

Creates a single instance that is cached in the store. Subsequent reads return the same instance.

```dart
final authServiceRef = Ref((store) => AuthService());

// Access it anywhere
final auth = authServiceRef.get($store);
```

#### `FactoryRef<T>` (Factory)

Creates a new instance every time it is retrieved.

```dart
final uuidRef = FactoryRef((store) => Uuid().v4());

final id1 = uuidRef.get($store);
final id2 = uuidRef.get($store); // id1 != id2
```

#### `FamilyRef<T, R>` (Parameterized)

Creates a unique instance for each unique argument provided.

```dart
final userProfileRef = FamilyRef<UserProfile, String>((store, userId) {
  return UserProfile(userId);
});

final userA = userProfileRef.get(store, 'A');
final userA_again = userProfileRef.get(store, 'A'); // Same instance
final userB = $store.get(userProfileRef('B')); // New instance
```

### 3. Reactivity & Watching

Impulse can watch for changes in your objects. If an object implements `ImpulseListenable` (like `ValueNotifier`), the `watch` method will trigger whenever it notifies.

```dart
final counterRef = Ref((store) => ValueNotifier(0));

final unwatch = $store.watch(counterRef(), (notifier) {
  print('Counter changed to: ${notifier.value}');
});

// Later, to stop watching:
unwatch();
```

### 4. Lifecycle & Disposal

Objects that implement `Disposable` are automatically disposed of when they are dropped from the store or when the store is reset. You can also provide a custom `dispose` callback in the reference definition.

```dart
final databaseRef = Ref(
  (store) => Database(),
  dispose: (store, db) => db.close(),
);
```

To remove an object from the store, you can use `drop`:

```dart
store.drop(myRef());
```

### 5. Testing

When testing dependency injection, you usually want to swap out dependencies on the fly. To do this, we can use `store.override`.

```dart
main(){
  test((){
    $store.override(someRef, (store) => MyMock());

    // To go back to the original constructor:
    $store.removeOverride(someRef);
  })
}
```

## Advanced Usage

### Pluggable Reactivity Adapters

Impulse uses a pluggable adapter system to handle how different types of objects are bound and disposed. By default, it supports `ImpulseListenable` (like `ValueNotifier`) and `Disposable`.

You can easily extend Impulse to support other patterns (like BLoC, Streams, or custom state types) by adding a `ReactivityAdapter`.

#### Example: BLoC Integration

```dart
class BlocAdapter implements ReactivityAdapter {
  @override
  void Function()? onBind(dynamic value, void Function() notify) {
    if (value is Bloc) {
      // Listen to the bloc's state changes
      final subscription = value.stream.listen((_) => notify());
      return () => subscription.cancel();
    }
    return null;
  }

  @override
  void onDispose(Store store, dynamic value) {
    if (value is Bloc) {
      // Automatically close the bloc when it's dropped from the store
      value.close();
    }
  }
}

// Register the adapter on the store
$store.reactivity.addAdapter(BlocAdapter());
```

Once registered, any reference that produces a `Bloc` will automatically be "watched" and "disposed" correctly by the store.

### Scoping References

To have a reference automatically be cleaned up after an operation, this package adds a helper function called `withScope`.

```dart
withScope(
  () async {
    // Perform operation
  },
  store: $store,
  refs: [
    refA(),
    refB(),
    refC(),
  ]
)
```

This runs the operation and cleans up all the refs after it is done. If there are multiple scopes using the same ref, it is cleaned up after the last scope stops using it.

## See also

- [impulse_flutter](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse_flutter/README.md) for a flutter integration using this package.
- [impulse_signals](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse_signals/README.md) for a signals addon to this package.
- [API reference](https://pub.dev/documentation/impulse/latest/) for a detailed description of all API points.

## License

This project is licensed under the MIT License.
