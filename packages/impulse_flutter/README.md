# Impulse Flutter

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg)](https://codecov.io/gh/Yoeri-z/impulse)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Flutter integration for [Impulse](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse/README.md), providing easy and simple state management and dependency injection for your Flutter applications.

> The package is currently being implemented in some production-level code to validate its real-world use. It will hit `1.0` after this is complete.

## Features

- **Type-safe Dependency Injection:** Define your objects and their dependencies using various reference types.
- **StoreScope:** Easily provide a `Store` to your entire widget tree or specific subtrees.
- **Widget access and rebuilding:** Use `ref.of(context)` for intuitive state access and widget rebuilding.
- **Automatic Lifecycle Management:** Objects are automatically disposed of when no longer needed by the widget tree.
- **Reactivity Integration:** Built-in support for `Listenable` and `ChangeNotifier`.

## Getting Started

Add `impulse_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  impulse_flutter: latest
```

## Core Concepts

### 1. The Store Scope

Wrap your widget tree with `StoreScope` to make the store available to the entire app.

```dart
void main() {
  runApp(
    StoreScope(
      child: const MyApp(),
    ),
  );
}
```

### 2. References

Define how your objects are created using `Ref`, `FactoryRef`, or `FamilyRef`.

```dart
final authServiceRef = Ref((store) => AuthService());
```

### 3. Binding and Retrieving

Use `ref.of(context)` to retrieve an instance and automatically rebuild the widget when its state changes or the reference is replaced.

```dart
@override
Widget build(BuildContext context) {
  final authService = authServiceRef.of(context);
  return Text(authService.user.name);
}
```

Use `ref.peek(context)` in the rare cases where you don't want the widget to depend on the object's lifecycle, or if you are inside `initState` or `dispose`, where `ref.of` would throw an error. Prefer to avoid `peek` when possible, as it can lead to unpredictable behavior, such as an object never being automatically disposed of.

```dart
ElevatedButton(
  onPressed: () => authServiceRef.peek(context).logout(),
  child: const Text('Logout'),
)
```

you can also access the global singleton store `$store` to retrieve objects from anywhere, if you didnt pass a `Store` to `StoreScope` it also uses `$store`

```dart
void login(){
  authServiceRef.get($store).login();
}
```

### 4. Testing

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

### Extending Reactivity (e.g., BLoC Integration)

Impulse uses a pluggable adapter system to handle how different types of objects are bound and disposed. You can easily add support for other patterns like BLoC by adding a `ReactivityAdapter`.

```dart
class BlocAdapter implements ReactivityAdapter {
  @override
  void Function()? onBind(dynamic value, void Function() notify) {
    if (value is Bloc) {
      // Listen to the bloc's state changes and trigger a rebuild
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

Once registered, any `Ref` that produces a `Bloc` can be used with `ref.of(context)`, and the widget will automatically rebuild on every state change.

## See also

- [impulse](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse/README.md) for core concepts and advanced usage.
- [impulse_signals](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse_signals/README.md) for signals integration.
- [API reference](https://pub.dev/documentation/impulse_flutter/latest/) for a detailed description of all API points.

## License

This project is licensed under the MIT License.
