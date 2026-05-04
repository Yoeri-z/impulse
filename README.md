# Impulse

[![Tests](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml/badge.svg)](https://github.com/Yoeri-z/impulse/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/Yoeri-z/impulse/graph/badge.svg)](https://codecov.io/gh/Yoeri-z/impulse)

A minimalist, type-safe state management and dependency injection ecosystem for Dart and Flutter.

This monorepo contains the following packages:

- **[Impulse Core](./packages/impulse/README.md)**: The core state management and DI registry for Dart.
- **[Impulse Flutter](./packages/impulse_flutter/README.md)**: A Flutter-centric extension that provides widgets and lifecycle-aware dependency injection.
- **[Impulse Signals](./packages/impulse_signals/README.md)**: An extension for `impulse_flutter` that adds support for `signals.dart` and also exports the `impulse_flutter` and `signals_flutter` libraries.

## Which one should I use?

- If you are building a **Pure Dart** application (CLI, Server), use `impulse`.
- If you are building a **Flutter** application, use `impulse_flutter` (which automatically includes `impulse`).
- If you like using signals, add `impulse_signals` along with `impulse_flutter`.
