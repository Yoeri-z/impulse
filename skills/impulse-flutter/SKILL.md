---
name: impulse-flutter
description: "Patterns for using impulse_flutter (state management & DI). Use when writing widgets, refs, notifiers, or tests with impulse_flutter."
---

# Impulse Flutter

State management & DI library built around three concepts:

- **Store**: a central container that caches active state objects and manages their lifecycle.
- **StoreScope**: a widget that provides the store to the widget tree (defaults to the global `$store` store) and tracks widget lifecycles.
- **Refs**: global definitions describing how a state object is created and its lifecycle. Widgets request objects through refs from the store.

`Ref` and `FamilyRef` increment their count when a widget depends on them and automatically call `dispose()` (on `ChangeNotifier`/`Disposable`) and drop the object from the store when the last widget unmounts. This means no manual lifecycle management.

## Setup

```bash
flutter pub add impulse_flutter
```

Wrap the app in a `StoreScope` and define refs globally:

```dart
final counterRef = Ref((store) => ValueNotifier(0));

void main() => runApp(const StoreScope(child: MyApp()));
```

## Refs

Pick the ref type based on the lifecycle you want, below are usage examples of each Ref type:

```dart
// Managed: cached single instance, disposed when the last dependent widget unmounts.
final authServiceRef = Ref((store) => AuthService(), dispose: (s) => s.cleanup());

// Singleton: never dropped until store.reset(); use when the object must survive
// even when no widget is currently using it.
final configRef = SingletonRef((store) => Config());

// Parametrized: one cached instance per input value (e.g. per id).
final chatRoomRef = FamilyRef<ChatController, String>(
  (store, roomId) => ChatController(roomId: roomId),
);
final chat = context.use(chatRoomRef('room-123'));

// Factory: no caching, a new instance per request; use for transient values.
final uuidRef = FactoryRef((store) => const Uuid().v4());

// Async: caches a FutureNotifier<T> that wraps the async call.
final userFutureRef = futureRef((store) async => getUser(store.get(userIdRef)));

// Stream: opens a stream subscription (cancels on dispose) and exposes its state reactively.
final messagesRef = streamRef((store) => api.watchMessages(store.get(roomIdRef)));
```

Inside ref creation callbacks and notifier bodies you can resolve other refs with `store.get(refRef)`. Sync `store` access must happen **before** the first async gap, otherwise a debug-mode error is triggered:

```dart
// wrong: store.get after await
futureRef((store) async { await doFoo(); return getUser(store.get(idRef)); });

// right
futureRef((store) async { final id = store.get(idRef); await doFoo(); return getUser(id); });
```

## Reading state in widgets

Two context extensions exist:

- `context.use(ref)`: registers a dependency, the widget rebuilds whenever the state notifies.
- `context.read(ref)`: no dependency registered; use in callbacks to mutate/read state without rebuilding. (Reading a managed ref without ever `use`-ing it triggers a debug-mode error.)

Prefer `Binder`/`Selector`/`Async*` widgets over `context.use`: they localize rebuilds to a small builder and are more explicit.

```dart
Binder(ref: authRef, builder: (context, auth) { /* rebuilds on every notify */ });

Selector(
  ref: counterRef,
  selector: (c) => c.count,
  builder: (context, count) => Text('$count'), // rebuilds only when count changes value
);
```

For small widgets `context.use` is fine:

```dart
final counter = context.use(counterRef); // rebuilds on notify
context.read(counterRef).value++;        // read without dependency (callbacks)
```

When the state is async, use `AsyncSelector`/`AsyncBuilder` which handle all three states:

```dart
AsyncBuilder(
  notifier: userNotifier, // a FutureNotifier or StreamNotifier
  loadingBuilder: (c, prev) => const CircularProgressIndicator(),
  dataBuilder: (c, user) => Text(user.name),
  errorBuilder: (c, err, st, prev) => Text(err.toString()),
);
```

## AsyncState

`FutureNotifier<T>` and `StreamNotifier<T>` expose their state as `AsyncState<T>` (`AsyncData`, `AsyncError`, `AsyncLoading`):

```dart
final notifier = store.get(userFutureRef);
final (user, err) = notifier();                       // destructure current state
switch (notifier.state) {
  AsyncData(:final value) => print('user: $value'),
  AsyncError(:final error) => print('error: $error'),
  AsyncLoading() => print('loading'),
}
notifier.refresh(); // re-subscribe while keeping old value/error
notifier.reload();  // re-subscribe, discarding old value/error
```

For fallible async work, use `attempt`, which returns a `Result` instead of throwing:

```dart
final (value, err) = (await attempt(() => foo())).unpacked;
if (err != null) { handleError(err); }
```

Optional: support third-party state objects (e.g. Cubit) by adding a `ReactivityAdapter` to `$store.reactivity` that subscribes on bind and cleans up on dispose.

## Widget-local Disposables

For objects scoped to a single `State` (a `TextEditingController`, a notifier sourced from widget state), use the `Disposables` mixin instead of a ref. It follows the same `create`/`reassemble`/`dispose` contract as refs; disposal routes through the store's reactivity system (`ChangeNotifier`/`Disposable` are auto-disposed):

```dart
class _ChatPageState extends State<ChatPage> with Disposables {
  late final textController = managed((store) => TextEditingController());

  late final messagesNotifier = managed(
    (store) => StreamNotifier(() => api.watchMessages(widget.roomId)),
    reassemble: (n) => n.reload(), // hot reload hook
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

Note: `managed` uses `StoreScope.of(context, depend: false)`, so it also works in `initState`. Use refs for cross-widget DI and `Disposables` for single-State scope.

## Testing

Use an isolated `Store` with reference overrides, never the global `$store` (which would leak state between tests):

```dart
setUp(() {
  testStore = createStore();
  mockApi = MockApiService();
  testStore.override(apiServiceRef, (store) => mockApi);
});

tearDown(() => testStore.reset()); // disposes everything, prevents leaks

await tester.pumpWidget(
  StoreScope(
    store: testStore,
    child: const MaterialApp(home: ProfileScreen()),
  ),
);
```
