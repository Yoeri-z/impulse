# Impulse Signals

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg)](https://codecov.io/gh/Yoeri-z/impulse)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Impulse extension for [`signals`](https://dartsignals.dev/) by Rody Davis. This package provides a `Controller` class that simplifies managing the lifecycle of multiple signals and effects, similar to `SignalsMixin`. It also exports `impulse_flutter` and `signals_flutter` so everything is neatly provided in a single library.

> The package is currently being implemented in some production-level code to validate its real-world use. It will hit `1.0` after this is complete.

## Features

- **Controller Base Class:** Group related signals and effects together.
- **Automatic Disposal:** Signals and effects created through the controller are automatically disposed of when the controller is dropped from the Impulse store.
- **Support for All Signal Types:** Includes helpers for standard signals, computed signals, future signals, stream signals, and more.

## Getting Started

Add `impulse_signals` to your `pubspec.yaml`:

```yaml
dependencies:
  impulse_signals: latest
```

## Usage Example

```dart
final themeControllerRef = Ref((store) => ThemeController());

class ThemeController extends Controller {
  // createSignal registers the signal for automatic disposal
  late final themeMode = createSignal(ThemeMode.system);
  late final seedColor = createSignal<Color>(Colors.deepPurple);

  // createComputed registers the computed signal for automatic disposal
  late final colorScheme = createComputed(() =>
    ColorScheme.fromSeed(seedColor: seedColor.value, brightness: Brightness.light)
  );

  void setThemeMode(ThemeMode mode) => themeMode.value = mode;
  void setSeedColor(Color color) => seedColor.value = color;
}
```

The package also adds a small method to work with errors.

```dart
final (value, err) = attempt(() => myApiCall(...));

// err is `AsyncError` from signals
// contains the error and the stacktrace
if(err != null){
  print('Error oh no! ${err.error}')
  print(err.stackTrace);
}

// value is value on succes
print('Retrieved value $value');
```

## See also

- [impulse](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse/README.md) for core concepts and advanced usage.
- [impulse_flutter](https://github.com/Yoeri-z/impulse/blob/main/packages/impulse_flutter/README.md) for Flutter integration.
- [API reference](https://pub.dev/documentation/impulse_signals/latest/) for a detailed description of all API points.

## License

This project is licensed under the MIT License.
