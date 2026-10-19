---
name: impulse-flutter
description: "Patterns for using impulse_flutter (state management & DI). Use when writing widgets, refs, notifiers, or tests with impulse_flutter."
---

# Impulse Flutter

State management & DI without code generation. Declare refs, let a store cache the objects, let widgets depend on them. Lifecycle is automatic: objects are disposed and dropped when the last dependent widget unmounts.

## Core concepts

- **Store**: central container that caches active state objects and manages their lifecycle. The default instance is the global `$store`; create isolated ones with `createStore()`.
- **StoreScope**: widget that provides a `Store` to the tree and tracks widget lifecycles so refs can be released when widgets unmount.
- **Ref**: global definition of how a state object is created and managed. Widgets request objects from the store through refs.

## Setup

```bash
flutter pub add impulse_flutter
```

Define refs globally, wrap the app in `StoreScope`:

```dart
final counterRef = Ref((store) => ValueNotifier(0)); // ChangeNotifier/Listenable supported natively

void main() => runApp(const StoreScope(child: MyApp()));
```

## Ref types

| Type | Behavior | Use for |
|---|---|---|
| `Ref<T>` | caches one instance, disposed + dropped when last dependent widget unmounts | default choice |
| `SingletonRef<T>` | cached until `store.reset()` | objects that must outlive widgets |
| `FamilyRef<T, R>` | one cached instance per parameter | per-id state (chat rooms, etc.) |
| `FactoryRef<T>` | no caching, new instance per request | transient values |

```dart
final authServiceRef = Ref((store) => AuthService(), dispose: (s) => s.cleanup());
final configRef = SingletonRef((store) => Config());
final chatRoomRef = FamilyRef<ChatController, String>(
  (store, roomId) => ChatController(roomId: roomId),
);
final uuidRef = FactoryRef((store) => const Uuid().v4());
```

Ref parameters for lifecycle control:

```dart
final authServiceRef = Ref(
  (store) => AuthService(),
  reassemble: (s) => ...,    // runs on hot reload while the object is alive
  recreateOnReassemble: true, // recreate the object (and its deps) on hot reload
  dispose: (s) => ...,        // override the default disposal logic
);
```

### Async refs

```dart
// Wraps the async call in a FutureNotifier<T>.
final userFutureRef = futureRef((store) async => getUser(store.get(userIdRef)));

// Wraps a stream subscription (cancelled on dispose) in a StreamNotifier<T>.
final messagesRef = streamRef((store) => api.watchMessages(store.get(roomIdRef)));
```

In ref callbacks, `store.get` must happen **before** the first `await` (debug-mode error otherwise):

```dart
// wrong
futureRef((store) async { await doFoo(); return getUser(store.get(idRef)); });

// right
futureRef((store) async { final id = store.get(idRef); await doFoo(); return getUser(id); });
```

## Reading state in widgets

- `context.use(ref)`: registers a dependency; the widget rebuilds when the object notifies.
- `context.read(ref)`: no dependency registered; for reading/mutating in callbacks and effects only.

```dart
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Count: ${context.use(counterRef).value}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read(counterRef).value++,
      ),
    );
  }
}
```

Prefer the binder widgets — they localize rebuilds and are more explicit. Use `context.use` only in small widgets.

```dart
Binder(ref: authRef, builder: (context, auth) { /* rebuilds on every notify */ });

Selector(
  ref: counterRef,
  selector: (c) => c.count,
  builder: (context, count) => Text('$count'), // rebuilds on value change only
);

AsyncSelector(
  ref: authRef,
  selector: (auth) => auth.userState, // an AsyncState
  loadingBuilder: (c, prev) => const CircularProgressIndicator(),
  dataBuilder: (c, user) => Text('Active user ${user.name}'),
  errorBuilder: (c, err, st, prev) => Text(err.toString()),
);

AsyncBuilder(
  notifier: messagesNotifier, // a FutureNotifier or StreamNotifier
  loadingBuilder: (c, prev) => const CircularProgressIndicator(),
  dataBuilder: (c, messages) => MessageList(messages),
  errorBuilder: (c, err, st, prev) => Text(err.toString()),
);
```

A `Ref`/`FamilyRef` that is only ever read (never `use`-d) is considered a memory leak and triggers a debug-mode error; use a `SingletonRef` if that's genuinely needed.

## AsyncState

`FutureNotifier<T>`/`StreamNotifier<T>` expose state as `AsyncState<T>` (`AsyncData`, `AsyncError`, `AsyncLoading`):

```dart
final notifier = store.get(userFutureRef);

final (user, err) = notifier(); // destructure current state
switch (notifier.state) {
  AsyncLoading() => print('loading'),
  AsyncData(:final value) => print(value),
  AsyncError(:final error) => print(error),
}

notifier.isLoading; notifier.hasValue; notifier.hasError;
notifier.value; notifier.error; notifier.stackTrace;

notifier.refresh(); // re-subscribe, keep old value/error
notifier.reload();  // re-subscribe, discard old value/error
```

`StreamNotifier` additionally exposes `notifier.isDone` (stream closed).

Fallible async work: use `attempt`, which returns a `Result` instead of throwing:

```dart
final (value, err) = (await attempt(() => foo())).unpacked;
if (err != null) { handleError(err); }
```

`FutureNotifier`/`StreamNotifier` can also be owned directly by a `State` when the value doesn't need sharing through the store. The constructor starts immediately, so create lazily and dispose:

```dart
class _FooState extends State<Foo> {
  late final StreamNotifier<List<Message>> messagesNotifier;

  @override
  void initState() {
    super.initState();
    messagesNotifier = StreamNotifier(() => api.watchMessages(widget.roomId));
  }

  @override
  void dispose() { messagesNotifier.dispose(); super.dispose(); }
}
```

## Widget-local Disposables

For objects scoped to a single `State` (e.g. `TextEditingController`, a notifier sourced from widget state), use the `Disposables` mixin instead of refs. Refs are for cross-widget DI. Same `create`/`reassemble`/`dispose` contract as refs; disposal routes through the store's reactivity system (`ChangeNotifier`/`Disposable` auto-disposed):

```dart
class _ChatPageState extends State<ChatPage> with Disposables {
  late final textController = managed((store) => TextEditingController());

  late final messagesNotifier = managed(
    () => StreamNotifier(() => api.watchMessages(widget.roomId)),
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

`managed` uses `StoreScope.of(context, depend: false)`, so it also works in `initState`.

## Testing

Use an isolated store with reference overrides — never the global `$store` (leaks state between tests):

```dart
setUp(() {
  testStore = createStore();
  mockApi = MockApiService();
  testStore.override(apiServiceRef, (store) => mockApi);
});

tearDown(() => testStore.reset()); // disposes everything

  testWidgets(..., (tester) async {
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
```

## Custom Reactivity (optional)

The default store handles `Listenable`/`ValueNotifier`/`ChangeNotifier`. Add a `ReactivityAdapter` to `$store.reactivity` for third-party state. Below is an example for making an adapter for Bloc:

```dart
class CubitReactivityAdapter implements ReactivityAdapter {
  const CubitReactivityAdapter();

  @override
  void Function()? onBind(dynamic value, void Function() notify) {
    if (value is BlocBase) {
      final sub = value.stream.listen((_) => notify());
      return () => sub.cancel();
    }
    return null;
  }

  @override
  void onDispose(dynamic value) {
    if (value is BlocBase) value.close();
  }
}

final store = createStore();
store.reactivity.addAdapter(const CubitReactivityAdapter());
```

## Rules (enforce these)

1. **Never use `context.read` for UI values.** Callbacks and effects only. If you need a read-only ref, use a `SingletonRef`.
2. **Prefer `Binder`/`Selector`/`AsyncSelector`/`AsyncBuilder` over `context.use`.** Use `context.use` only in small widgets.
3. **Call `context.use` exactly at the site where the value is used** — it's cheap, and it localizes rebuilds.
4. **Resolve `store.get` before the first `await` in ref callbacks.** Debug-mode error otherwise.
5. **In tests, always use `createStore()` + `override`, never the global `$store`.** Reset in `tearDown`.
6. **Widget-local state uses the `Disposables` mixin, not refs.** Refs are for cross-widget DI only.
7. **Pick the ref type deliberately**: `Ref` by default, `SingletonRef` only when the object must outlive widgets, `FamilyRef` for per-parameter state, `FactoryRef` for transient values.
