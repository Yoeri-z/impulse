# Impulse Flutter

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg)](https://codecov.io/gh/Yoeri-z/impulse)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Impulse Flutter is a state management and dependency injection library for Flutter. It provides central state containers, dependency tracking, and automatic lifecycle management.

---

## Features

- **No Code Generation**: Requires no build runner or pre-compilation steps.
- **Automatic Garbage Collection**: States are disposed of and dropped from the store when no active widgets are listening.
- **Dependency Injection**: Declare type-safe references and retrieve or override them as needed.
- **Flutter Integration**: Built-in support for standard Flutter `Listenable` and `ChangeNotifier` classes.
- **Testable**: Supports isolated stores and reference overrides for widget and unit testing.
- **Flexible**: The package is designed as a simple and controllable dependency and reactivity registry that works with any piece of state. It easily combines with other packages.

---

## Quick Start

Add Impulse Flutter to your project:

```bash
flutter pub add impulse_flutter
```

Below is a complete example of a simple counter application:

```dart
import 'package:flutter/material.dart';
import 'package:impulse_flutter/impulse_flutter.dart';

// 1. Define a reference to a state class (ChangeNotifier is supported natively)
final counterRef = Ref((store) => ValueNotifier(0));

void main() {
  runApp(
    // 2. Wrap your application in a StoreScope
    const StoreScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CounterPage(),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impulse Counter Example')),
      body: Center(
        child: Text(
          // 3. Make the widget depend on state
          // a widget can hold at most one dependency per reference
          // calling this multiple times has (basically) no effect on performance
          'Count: ${context.use(counterRef).value}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // 4. Use .read(context) to read the state without creating a widget dependency
        onPressed: () => context.read(counterRef).value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## Core Concepts

Impulse revolves around three primary concepts: the Store, StoreScope, and References.

### 1. The Store & StoreScope

- **The Store**: A central container where all active states and dependencies are cached and managed.
- **StoreScope**: A Flutter widget that provides a `Store` to the widget tree. By default, it creates its own `Store` instance and passes it to the descendants. You can also pass in your own instance. It tracks widget lifecycles to automatically release references when widgets unmount.

---

### 2. Reference Types

References are definitions that describe how state objects are created and managed. They are declared globally and are used to request objects from the store:

#### 1. `Ref<T>` (Managed Reference)

Caches a single instance of `T` in the store. By default, it is dropped from the store when its reference count reaches zero.

```dart
final authServiceRef = Ref(
  (store) => AuthService(),
);
```

#### 2. `SingletonRef<T>` (Singleton Reference)

Caches a single instance of `T` in the store forever (until the store is reset).

```dart
final authServiceRef = SingletonRef(
  (store) => AuthService(),
);
```

#### 3. `FamilyRef<T, R>` (Parametrized Reference)

Caches unique instances of `T` associated with an input parameter of type `R`.

```dart
final chatRoomRef = FamilyRef<ChatController, String>(
  (store, roomId) => ChatController(roomId: roomId),
);

// Usage in widget:
final chat = context.use(chatRoomRef('room-123'));
```

#### 4. `FactoryRef<T>` (Factory Reference)

Does not cache instances. It evaluates the creation callback and returns a new instance of `T` every time it is requested.

```dart
final uuidRef = FactoryRef((store) => const Uuid().v4());
```

#### Parameters
References have a number of parameters to exert control over the object's lifecycle.

```dart
final authServiceRef = Ref(
  (store) => AuthService(),
  reassemble: (service) => ...  // Modify the services if a reassemble (hot reload) happens while it is alive.
  recreateOnReassemble: true    // Recreates the object on reassemble. Essentially this means that this specific object
                                // and all its dependencies do a "hot restart" when you hot reload. 
                                // By default this is set to false.
  dispose: (service) => ...     // override the default disposal adapters with custom dispose logic. 
                                //(see the Reactivity adapters sections)
);
```

#### Dependency tracking
References automatically track dependencies. This means that the object is recreated if any of its dependencies change.

```dart
final apiClientRef = Ref((store) => ApiClient());

// if the api client ever gets replaced or overriden 
// the auth service is recreated.
// Also notice that in this example the api client is an implicit singleton because
// it is depended upon by a singleton.
final authServiceRef = SingletonRef(
  (store) => AuthService(store.get(apiClientRef)), 
);
```

### Helpers

Some convenience functions are available that create a `Ref` wrapping a special notifier object.

#### `futureRef<T>` (Handling futures)

`futureRef` is a function that returns a `Ref` with a `FutureNotifier<T>` object. A `FutureNotifier<T>` is a special notifier that wraps an async call with a neat interface and exposes its state as an `AsyncValue<T>`.
```dart
final userFutureRef = futureRef((store) async => await getUser(store.get(userId)));

final notifier = store.get(userFutureRef);

// You can call the notifier directly to destructure the current state:
final (user, err) = notifier();

// Or pattern-match on the state:
switch (notifier.state) {
  AsyncLoading() => print('Loading...'),
  AsyncData(:final value) => print('User: ${value.name}'),
  AsyncError(:final error) => print('Error: $error'),
}

// The notifier also exposes various convenience properties:
notifier.isLoading;
notifier.hasValue;
notifier.hasError;
notifier.value;
notifier.error;
notifier.stackTrace;

// to refresh without discarding the old value or error
notifier.refresh();

// to reload, discarding old value or error
notifier.reload();
```
You may only use the store to get other references before introducing an async gap.
```dart
// this is not allowed
futureRef((store) async{  
  await doFoo();
  
  return await getUser(store.get(idRef));
});


// this is allowed
futureRef((store) async{  
  final userId = store.get(idRef);

  await doFoo();
  
  return await getUser(userId);
});
```

#### `streamRef<T>` (Handling streams)

`streamRef` is a function that returns a `Ref` with a `StreamNotifier<T>` object. A `StreamNotifier<T>` wraps a subscription to a stream and exposes its state reactively.

```dart
final chatMessagesRef = streamRef((store) => api.watchMessages(store.get(roomIdRef)));

final notifier = store.get(chatMessagesRef);

// You can call the notifier directly to destructure the current state:
final (messages, err) = notifier();

// Or pattern-match on the state:
switch (notifier.state) {
  AsyncLoading() => print('Loading...'),
  AsyncData(:final value) => print('Messages: $value'),
  AsyncError(:final error) => print('Error: $error'),
}

// The notifier also exposes various convenience properties:
notifier.isLoading;
notifier.hasValue;
notifier.hasError;
notifier.isDone;      // True if the underlying stream has closed
notifier.value;
notifier.error;
notifier.stackTrace;

// to refresh (re-subscribe) without discarding the old value or error
notifier.refresh();

// to reload (re-subscribe), immediately discarding old value or error
notifier.reload();
```

#### Using `FutureNotifier` and `StreamNotifier`

`FutureNotifier` and `StreamNotifier` can also be used without refs and stores, e.g. owned by a `StatefulWidget`. This is often useful because most async calls do not actually need to be shared through the `StoreScope`. Note that the constructor starts the future/subscription immediately, so create the notifier lazily (e.g. in `initState`) and `dispose()` it when done.

```dart
class _ChatPageState extends State<ChatPage> {
  late final StreamNotifier<List<Message>> messagesNotifier;

  @override
  void initState() {
    super.initState();
    messagesNotifier = StreamNotifier(
      () => api.watchMessages(widget.roomId),
      onError: (e, st) => logErr(e), // also: onData / onDone
    );
  }

  @override
  void dispose() {
    messagesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBuilder(
      notifier: messagesNotifier,
      loadingBuilder: (context, _) => const CircularProgressIndicator(),
      dataBuilder: (context, messages) => MessageList(messages),
      errorBuilder: (context, err, st, _) => Text(err.toString()),
    );
  }
}
```

`FutureNotifier(() => fetchUser(widget.roomId), onSuccess: ..., onError: ...)` works the same way.

---

## Reading State in Widgets

Widgets interact with references using context-based extensions. There are two primary methods for retrieving state objects:

### 1. `context.use(ref)`

Makes the widget depend on the state object. The widget will automatically rebuild whenever the state object notifies of a change. `context.use` can be called multiple times at nearly no cost; prefer using it exactly at the site where the value is used.

```dart
@override
Widget build(BuildContext context) {
  return Text('Name: ${context.use(userProfileRef).name}');
}
```

### 2. `context.read(ref)`

Retrieves the state object without registering a dependency. The widget will not rebuild when the state object changes.
Only use this in callbacks and effects, never use `context.read` to retrieve values for the UI.

```dart
ElevatedButton(
  onPressed: () {
    context.read(authControllerRef).logout();
  },
  child: const Text('Log Out'),
)
```

| A `Ref` or `FamilyRef` read without ever being used will trigger an error when running in debug mode since it is considered a memory leak.
| If you encounter a situation where this is required, consider using a `SingletonRef` instead.

---

### Selector and Binder widgets

To localize rebuilds, selector and bind widgets are available.

```dart
Binder(
  ref: authRef,
  builder: (context, auth){
    //rebuilds whenever auth changes or notifies
  }
)

Selector(
  ref: counterRef,
  selector: (counter) => counter.count,
  builder: (context, count){
    // rebuilds whenever the count changes to a different value than it previously was.
  }
)

AsyncSelector(
  ref: authRef,
  selector: (auth) => auth.userState, // assuming it returns an AsyncValue
  loadingBuilder: (context, previousValue) => const CircularProgressIndicator(),
  dataBuilder: (context, user) => Text('Active user ${user.name}'),
  errorBuilder: (context, err, st, previousValue) => Text(err.toString()),
)

AsyncBuilder(
  notifier: authFutureNotifier, // a FutureNotifier or StreamNotifier
  loadingBuilder: (context, previousValue) => const CircularProgressIndicator(),
  dataBuilder: (context, user) => Text('Active user ${user.name}'),
  errorBuilder: (context, err, st, previousValue) => Text(err.toString()),
)

```

For code hygiene it is preferred to use these widgets over the `context.use` method. These widgets are more explicit and readable. They also localize rebuilds which can have a noticeable effect on performance in some cases.

For small widgets `context.use` is fine and might even be preferred.

## Handling errors

Impulse includes a functional error-handling utility to deal with operations that might fail (e.g., network requests, file I/O).

- **`AsyncState<T>`**: A sealed class with subclasses `AsyncData`, `AsyncError` and `AsyncLoading` for pattern matching.
- **`attempt`**: A utility function that wraps an asynchronous execution, returning a `Result<T>` without throwing.

```dart
void main() async {
  final result = await attempt(() => foo());

  if (result is AsyncFailure<String>) {
    logErr(result);
    return;
  }

  print('Fetched value: ${result.value!}');

  // in functions, pattern matching is often messy.
  // this is why this package adds an `unpacked` getter.
  
  final (value, err) = await attempt(() => bar()).unpacked;

  if (err != null) {
    logErr(err);
  }

  print('Fetched value: ${value!}');
}
```

## Memory Management

Impulse automatically handles the lifecycle of state objects using reference counting if your reference is made with `Ref` or `FamilyRef`:

1. When a widget retrieves an object via `context.use(ref)`, the object's reference count is incremented.
2. If multiple widgets listen to the same reference, the count increases accordingly.
3. When widgets are popped or unmounted from the screen, the count is decremented.
4. When the reference count reaches zero, the object is automatically disposed of (calling `dispose()` if it implements `ChangeNotifier` or `Disposable`) and dropped from the store.

```dart
final appThemeRef = Ref(
  (store) => AppTheme(),
);
```

If you don't want this behavior consider using a `SingletonRef` or a `FactoryRef`

---

## Widget-local Disposables

Not everything belongs in the store. Some objects only make sense within a single widget (a `TextEditingController`, a `FutureNotifier` sourced from widget state). The `Disposables` mixin manages disposal of such objects for a `State`.

It follows the same `create`/`reassemble`/`dispose` contract as `Ref`: the object is created on first access, recreated or updated on hot reload, and disposed when the state is disposed. Disposal goes through the store's reactivity system, so any type the configured `ReactivityAdapter`s handle (such as `ChangeNotifier` or `Disposable`) is disposed automatically.

```dart
class _ChatPageState extends State<ChatPage> with Disposables {
  late final textController = managed((store) => TextEditingController());

  late final messagesNotifier = managed(
    () => StreamNotifier((store) => api.watchMessages(widget.roomId)),
    reassemble: (n) => n.reload(),
  );

  @override
  Widget build(BuildContext context) {
    return AsyncBuilder(
      notifier: messagesNotifier,
      loadingBuilder: (context, _) => const CircularProgressIndicator(),
      dataBuilder: (context, messages) => MessageList(messages),
      errorBuilder: (context, err, st, _) => Text(err.toString()),
    );
  }
}
```

Use refs for objects that participate in dependency injection across the widget tree, and `Disposables` for objects scoped to a single `State`.

---

## Testing & Overrides

You can mock dependencies in unit and widget tests by providing reference overrides inside isolated store instances.

### Widget Testing Example

To test widgets in isolation, create a local `Store`, configure overrides, and pass it to a `StoreScope`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse_flutter/impulse_flutter.dart';
import 'package:mocktail/mocktail.dart';

final apiServiceRef = Ref((store) => RealApiService());

class MockApiService extends Mock implements RealApiService {}

void main() {
  late Store testStore;
  late MockApiService mockApi;

  setUp(() {
    testStore = createStore(); // Isolated store instance for this test
    mockApi = MockApiService();

    // Override the RealApiService reference
    testStore.override(apiServiceRef, (store) => mockApi);
  });

  tearDown(() {
    // Reset the store to dispose of all objects and prevent tests from leaking state
    testStore.reset();
  });

  testWidgets('Renders profiles correctly with overridden API', (tester) async {
    when(() => mockApi.getUserName()).thenAnswer((_) async => 'Test Mock User');

    await tester.pumpWidget(
      StoreScope(
        store: testStore, // Supply the isolated test store
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    expect(find.text('Test Mock User'), findsOneWidget);
  });
}
```

---

## Advanced Usage

### Custom Reactivity Adapters

By default, the store created through `createStore()` supports Flutter's standard `Listenable`, `ValueNotifier`, and `ChangeNotifier` classes.

You can add custom `ReactivityAdapter`s to integrate third-party state managers or streams. Below is an example of an adapter for Cubit/BLoC:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:impulse_flutter/impulse_flutter.dart';

class CubitReactivityAdapter implements ReactivityAdapter {
  const CubitReactivityAdapter();

  @override
  void Function()? onBind(dynamic value, void Function() notify) {
    if (value is BlocBase) {
      // Rebuild dependent widgets when the Cubit/Bloc emits a new state
      final subscription = value.stream.listen((_) => notify());
      return () => subscription.cancel();
    }
    return null;
  }

  @override
  void onDispose(dynamic value) {
    if (value is BlocBase) {
      // Close the Cubit/Bloc when dropped from the store
      value.close();
    }
  }
}

void main() {
  final store = createStore();
  // Register the adapter globally
  store.reactivity.addAdapter(const CubitReactivityAdapter());

  runApp(const StoreScope(child: MyApp()));
}
```

---


## Why Impulse

Impulse is a state management and dependency injection library that lets you register any object in a store and make widgets depend on it. This section compares it to other popular solutions and describes the trade-offs involved. Be warned, this section is opinionated.

### Compared to Riverpod

Riverpod is the most similar solution to Impulse. Impulse uses the same reference model: you declare refs that describe how an object is created, and the store caches and manages instances based on those refs.

The difference is in how widgets consume that state. Riverpod recommends `ConsumerWidget` or `ConsumerStatefulWidget`, which replaces the standard `StatelessWidget` and `StatefulWidget` classes. Reading and mutating state happens through the `ref` object that these widgets receive, which means imperative calls end up inside the `build` method. This breaks with the core primitives of Flutter, where `build` is meant to be a pure description of the UI.

Impulse keeps the standard widget classes and the standard `build` method. Widgets bind to a ref explicitly through the `Binder`, `Selector` and `AsyncSelector` widgets, and mutate state from event handlers, callbacks, or controllers. State changes happen where events happen, not inside `build`.

Another difference is that Riverpod bakes its behaviors into the provider itself, which gives you a large family of provider types to pick from. Impulse keeps its references dumb and puts that responsibility on the registered objects instead.

Refs in Impulse are also designed to work with Flutter natives and a wider range of objects. Plain `Listenable`s, `ChangeNotifier`s and arbitrary objects can be registered, tracked and disposed of without being wrapped in provider specific types. They also give you more control over reassemble behavior.

### Compared to Bloc / Provider

Bloc is essentially Provider with a `Bloc` and `Cubit` class. Those classes work with Impulse too: you can register a bloc or cubit like any other object and dispose of it automatically.

The difference with Provider is how the wiring is declared. With Provider, composing dependencies means stacking providers and wiring them together by hand, and resolving a dependency by type from higher up the tree is weak. With Impulse, a ref declares what an object is, how it is created, and what it depends on in a single place. This makes the dependency graph more declarative and easier to reason about.

### Compared to Signals

Signals solves reactivity well but offers little in terms of dependency injection. Signals are just primitives, very flexible but not very pragmatic on their own. In those cases Impulse can replace signals entirely, or be used alongside them.

A more opinionated note: signals often make things more complex than they need to be once you go beyond simple use cases. Reactive graphs tend to grow in places where a plain, managed object would have been simpler. There is the performance argument that signals provide more fine-grained reactivity, but in reality Flutter is already very efficient in computing its rebuilds and there is really no need for it.

---

## License

This project is licensed under the MIT License.
