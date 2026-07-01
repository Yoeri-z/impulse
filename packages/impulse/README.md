# Impulse

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg?flag=impulse)](https://codecov.io/gh/Yoeri-z/impulse)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Easy and simple state management solution that mainly functions as a dependency injection service and integrates well with other state management solutions.

Impulse provides a lightweight way to manage shared state and dependencies using a central `Store` and type-safe `References`.

> The package is currently being implemented in some production-level code to validate its real-world use. It will hit `1.0` after this is complete.

## Quick start

Add Impulse to your project:

```bash
dart pub add impulse
```

Below is a minimal example showing how to define a reference, retrieve it, watch for updates, and notify dependents:

```dart
import 'package:impulse/impulse.dart';

// 1. Define a Reference (Ref)
final counterRef = Ref((store) => Counter());

class Counter extends ImpulseNotifier {
  int count = 0;

  void increment() {
    count += 1;
    notify(); // Notifies the store and all listening dependents
  }
}

void main() async {
  // 2. Watch for changes (using the global $store)
  final unwatch = $store.watch(counterRef, (counter) {
    print('Count is ${counter.count}');
  });

  // 3. Retrieve the instance and update it
  $store.get(counterRef).increment();

  // Cleanup when done
  unwatch();
  $store.reset();
}
```

---

## Refs & the store

### The Store

The `Store` is the central container where all of your dependencies and shared states live.

- **Global Store**: Impulse provides a global default store instance named `$store`. For most applications, this is the only store you will need.
- **Local Stores**: You can construct a new isolated store via `Store()`. This is particularly useful for hermetic testing or scoping specific modules of an application.

Key Store API methods:

- `store.get(ref)`: Retrieves or initializes the object associated with the reference.
- `store.init(ref)`: Initializes a reference immediately without returning its value.
- `store.watch(ref, callback)`: Listens for notifications from the reference's object and invokes the callback. Returns an unwatch function.
- `store.drop(ref)`: Manually removes the reference's object from the store and disposes of it.
- `store.reset()`: Disposes of all stored objects and clears the store.
- `store.reassemble()`: Forces a re-evaluation of all dependencies (highly useful for Flutter's Hot Reload).

---

### Reference Types

References define how dependencies are created, cached, and disposed. Impulse provides three primary reference types:

#### 1. `Ref<T>` (Singleton Reference)

Caches a single instance of `T` globally within the store.

```dart
final authServiceRef = Ref(
  (store) => AuthService(),
  dispose: (service) => service.close(),
);
```

#### 2 `SingletonRef<T>` (Singleton Reference)

Caches a single instance of `T` in the store. By default, it is dropped from the store when its reference count reaches zero.

```dart
final authServiceRef = Ref(
  (store) => AuthService(),
  dispose: (service) => service.cleanup(), // Optional manual cleanup callback
);
```

#### 3. `FactoryRef<T>` (Factory Reference)

Never caches the value. It creates and returns a brand-new instance of `T` every time it is requested from the store.

```dart
final uuidRef = FactoryRef((store) => const Uuid().v4());
```

#### 4. `FamilyRef<T, R>` (Parametrized Reference)

Caches unique instances based on an input parameter of type `R`. Perfect for parametrized data fetches or services.

```dart
final userProfileRef = FamilyRef<UserProfile, String>(
  (store, userId) => UserProfile(userId: userId),
);

// Usage:
final profileA = store.get(userProfileRef('Alice'));
final profileB = store.get(userProfileRef('Bob'));
```

---

## `ImpulseNotifier` and error handling

### `ImpulseNotifier`

State objects can extend `ImpulseNotifier` to gain reactive capabilities. `ImpulseNotifier` implements `ImpulseListenable` and `Disposable` under the hood. When your state class calls `notify()`, all dependent boxes and active watchers are notified immediately, triggering cascading updates.

```dart
class ThemeState extends ImpulseNotifier {
  bool isDarkMode = false;

  void toggle() {
    isDarkMode = !isDarkMode;
    notify(); // Automatically triggers invalidation of any dependent Refs
  }
}
```

---

### Error Handling with `Result<T>` and `attempt`

Impulse includes a functional error-handling utility to deal with operations that might fail (e.g., network requests, file I/O).

- **`Result<T>`**: A type alias representing the record `(T? value, Err? err)`.
- **`attempt`**: A utility function that wraps an asynchronous execution, returning a `Result<T>` without throwing.
- **`MapResult` Extension**: Exposes a `.map()` method to gracefully handle the success, failure, or empty state of a `Result`.

```dart
import 'package:impulse/impulse.dart';

Future<String> fetchData() async {
  // Can throw an error
  return throw Exception('Network timeout');
}

void main() async {
  final (value, err) = await attempt(() => fetchData());

  if (err != null) {
    print('Fetch failed: ${err.error}');
    return;
  }

  print('Fetched value: $value');
}
```

---

## Testing

Impulse makes testing simple and hermetic by providing dependency overrides and allowing you to instantiate local, isolated stores.

### 1. Using Overrides

You can mock or stub any reference in the store. When a reference is overridden, any dependent references will automatically adapt and use the overridden version.

```dart
import 'package:test/test.dart';
import 'package:impulse/impulse.dart';

final apiRef = Ref((store) => RealApiService());
final repositoryRef = Ref((store) => UserRepository(apiRef.get(store)));

class MockApiService implements RealApiService {
  @override
  Future<String> getUserName() async => 'Mock User';
}

void main() {
  late Store store;

  setUp(() {
    store = Store(); // Use a local store instead of global $store
  });

  tearDown(() {
    // Reset the store to dispose of all objects and prevent tests from leaking state
    store.reset();
  });

  test('UserRepository uses the overridden API service', () async {
    // Override the RealApiService with MockApiService on this store
    store.override(apiRef, (store) => MockApiService());

    final api = store.get(apiRef);
    expect(await api.getUserName(), equals('Mock User'));
  });
}
```

### 2. Isolation & Resetting

- **Isolation**: Always use local, isolated `Store()` instances in your tests instead of the global `$store` to ensure tests run in isolation and do not share state.
- **Resetting**: In your test suite's `tearDown` or `setUp` callback, call `store.reset()`. This guarantees that all cached references are completely cleared and resources (like controllers or listeners) are properly disposed of, avoiding state bleeding between tests.

---

## Advanced

### Interfaces

Impulse relies on a set of core abstract interfaces to manage object lifecycles:

- **`Disposable`**: An interface for classes that require manual resource cleanup.
  ```dart
  abstract class Disposable {
    void dispose();
  }
  ```
- **`ImpulseListenable`**: An interface for objects that can be listened to for state changes.
  ```dart
  abstract class ImpulseListenable {
    void addListener(Listener listener);
    void removeListener(Listener listener);
  }
  ```
- **`ReactivityAdapter`**: An adapter interface defining how to bind to and dispose of specific object types within the store.
  ```dart
  abstract class ReactivityAdapter {
    void Function()? onBind(dynamic value, void Function() notify);
    void onDispose(Store store, dynamic value);
  }
  ```

---

### Reactivity delegate (with example for BLoC)

The `ReactivityDelegate` coordinates custom bindings and disposals. By default, it supports objects implementing `ImpulseListenable` and `Disposable`. However, you can register custom `ReactivityAdapter`s to support external libraries or other state management solutions (like BLoC or Streams).

Here is an example adapter for integrating BLoC/Cubit:

```dart
import 'package:bloc/bloc.dart';
import 'package:impulse/impulse.dart';

class BlocReactivityAdapter implements ReactivityAdapter {
  const BlocReactivityAdapter();

  @override
  void Function()? onBind(dynamic value, void Function() notify) {
    if (value is BlocBase) {
      // Whenever the Bloc/Cubit emits a new state, notify downstream dependents
      final subscription = value.stream.listen((_) => notify());
      return () => subscription.cancel();
    }
    return null;
  }

  @override
  void onDispose(Store store, dynamic value) {
    if (value is BlocBase) {
      // Automatically close the Bloc when it is dropped from the store
      value.close();
    }
  }
}

// Option A: Register the adapter on the global default `$store`
$store.reactivity.addAdapter(const BlocReactivityAdapter());

// Option B: Register the adapter when instantiating a custom local Store
final customStore = Store(
  delegate: ReactivityDelegate(
    adapters: [const BlocReactivityAdapter()],
  ),
);
```

---

### Scopes

The `withScope` function allows you to temporarily retain a reference in the store for the duration of an asynchronous callback. Once the callback completes (or throws), the reference is released. If its reference count drops to 0, it is automatically dropped and cleaned up.

```dart
final tempCacheRef = Ref((store) => TemporaryCache());

void main() async {
  final result = await withScope(
    (store) async {
      final cache = store.get(tempCacheRef);
      return await cache.loadSessionData();
    },
    store: $store,
    ref: tempCacheRef,
  );

  // Outside the scope, tempCacheRef has been automatically released and disposed!
  print($store.exists(tempCacheRef)); // false
}
```

---

### The box model

Under the hood, Impulse organizes references in a directed dependency graph using a container called `ImpulseBox`.

```
[Dependent Box]
      │
      ├─► (reads & watches) ──► [Dependency Box A]
      └─► (reads & watches) ──► [Dependency Box B]
```

When you call `store.get(ref)` or `store.watch(ref)`:

1. **Lazy Evaluation**: The reference's `create` callback is only evaluated when needed.
2. **Automatic Dependency Tracking**: During evaluation, Impulse sets an active evaluation context. If your creator callback reads another reference (e.g., `store.get(otherRef)`), Impulse dynamically registers that `otherRef`'s box as a **dependency**, and the current box as a **dependent**.
3. **Reactive Invalidation**: When a dependency notifies (or is replaced/reset), it recursively invalidates and resets all its dependents, causing them to re-evaluate and rebuild their state seamlessly.
4. **Reference Counting & GC**: Every dependency relation acts as a retain lock. If a box is not configured with `keepAlive: true`, it tracks the number of active dependents and manual watchers. As soon as this count hits zero, the box cleanly tears itself down (calling the `ReactivityDelegate`'s `onDispose` and its own custom `dispose` callback) and removes itself from the store to save memory.

---

## See also

- [impulse_flutter](https://pub.dev/packages/impulse_flutter) for a flutter integration using this package.
- [impulse_signals](https://pub.dev/packages/impulse_signals) for a signals addon to this package.
- [API reference](https://pub.dev/documentation/impulse/latest/) for a detailed description of all API points.

## License

This project is licensed under the MIT License.
