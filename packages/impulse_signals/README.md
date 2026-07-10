# Impulse Signals

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg)](https://codecov.io/gh/Yoeri-z/impulse)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Impulse extension for [`signals`](https://dartsignals.dev/) by Rody Davis. This package provides a `Controller` class that simplifies managing the lifecycle of multiple signals and effects, similar to `SignalsMixin`. It also exports `impulse_flutter` and `signals_flutter` so everything is neatly provided in a single library.

## Features

- **Controller Base Class:** Group related signals and effects together.
- **Automatic Disposal:** Signals and effects created through the controller are automatically disposed of when the controller is dropped from the Impulse store.
- **Support for All Signal Types:** Includes helpers for standard signals, computed signals, future signals, stream signals, and more.

## Getting Started

Add `impulse_signals`:

```
flutter pub add impulse_signals
```

This readme is very brief and assumes you already know how `impulse_flutter` works. Read the `impulse_flutter` documentation [here](https://pub.dev/packages/impulse_flutter).

## Usage Example

```dart
// 1. Define a reference to a Controller
final counterRef = Ref((store) => CounterController());

// 2. Define a controller
class CounterController extends Controller {
  // 3. create various singals using createX functions
  late final count = createSignal(0);
  late final countEven = createComputed(() => count.value % 2 == 0);

  void increment() => count.value++;
}

void main() {
  runApp(
    // 4. Wrap your application in a StoreScope
    const StoreScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CounterPage());
  }
}

class CounterPage extends SignalWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 5. Depend on the controller
    final controller = context.use(counterRef);

    return Scaffold(
      appBar: AppBar(title: const Text('Impulse Counter Example')),
      body: Center(
        child: Column(
          children: [
            // 6. read signals from the controller
            Text(
              'Count: ${controller.count.value}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Count is ${controller.countEven.value ? 'even' : 'odd'}.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}

```

## Modified reactivity

The package modifies how the store reacts to `ChangeNotifier`. If a value is a signal reactivity is disabled. This means it is safe to provide signals using `Ref`. It also automatically disposes signals whenever the `Ref` gets disposed. Behavior regarding `ChangeNotifiers` is otherwise unchanged and will behave exactly the same as it does in `signals_flutter`.

## See also

- [impulse](https://pub.dev/packages/impulse) for core concepts and advanced usage.
- [impulse_flutter](https://pub.dev/packages/impulse_flutter) for a full documentation of `impulse` and how to use it in Flutter.
- [API reference](https://pub.dev/documentation/impulse_signals/latest/) for a detailed description of all API points.

## License

This project is licensed under the MIT License.
