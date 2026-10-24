## 0.12.0
- Added `AsyncResult`, the resolved part of `AsyncState` (`AsyncData`/`AsyncFailure`), as the pattern for data-side fallible calls without loading states:
  - `AsyncResult.guard` wraps a fallible call; throws (async or sync) become an `AsyncFailure`.
  - `mapData`/`mapDataAsync` chain fallible work; failures propagate untouched (including `previousValue`). `mapDataAsync` wraps the chained call by default (`wrap: false` to disable).
  - `recover`, `getOr` for fallbacks, `fold` for the exhaustive two-way match.
- `AsyncData` and `AsyncFailure` now extend `AsyncResult`.
- Added `AsyncState.onFailure` for logging failures without breaking the flow.
- Removed `attempt`, the `Result` classes (`Ok`/`Failure`), the `unpacked`/`Unpacked` destructuring API and `AsyncState.fromResult`; use `AsyncResult.guard` and its combinators instead (breaking).

## 0.11.1
- README polish: fixed typos and awkward wording.

## 0.11.0
- Fixed a reference leak when reading the same dependency multiple times during one evaluation.
- Fixed a crash when producing a nullable value.
- Fixed a crash when notifying listeners reentrantly.
- `Store.select` no longer swallows `null` selections.
- `FutureNotifier` no longer applies failures from discarded runs.
- Removed the unused `onlyOnDependencyChange` parameter from `Store.select`.
- `FutureNotifier`/`StreamNotifier` callbacks are now private and only provided through the constructors.
- `ImpulseBox.retain`/`ImpulseBox.release` are now internal and `ImpulseBox.uninitialized` is private.
- Fixed the error message of `AsyncData.asFailure`.
- Requires Dart `3.12` or newer.

## 0.10.0
- Added `recreateOnReassemble` parameter to `ImpulseReference`. When enabled, `reassemble()` fully recreates the object through its factory (like a "hot restart" for that object) instead of invoking the `reassemble` callback.
- Fixed outdated code documentation.

## 0.9.0
- Removed `AsyncResult`
- removed `store` parameter from onDispose method in the `ReactivityAdapter` interface

## 0.7.0
- Changed `ImpulseNotifier` implementation to higher performance variant (based on flutters implementation)
- Renamed: `Task` to `FutureNotifier`, `StreamTask` to `StreamNotifier`, `ResultContainer` to `ResultListenable` and 
- Removed the record based error handling pattern in favour of `AsyncState` sealed class pattern matching

## 0.6.3
- Made interface for `Task` and `StreamTask`.

## 0.6.2
- Added some getters to the `ResultExtension`.

## 0.6.1
- bumped version to match version of other packages.
- added `streamRef` and `StreamTask`.

## 0.6.0
- Jumped multiple versions to sync up with the other packages.
- Added `Task` and `taskRef`.
- Added `disposed` flag to `ImpulseNotifier`.

## 0.3.0

- Simplified reference creation: `Ref`, `FactoryRef`, and `SingletonRef` now directly inherit from `ImpulseReference`.
- Removed `KeylessRef` interface and empty invocation parentheses `()` when retrieving or watching refs (e.g. use `store.get(myRef)` instead of `store.get(myRef())`).
- Integrated `withScope` directly into the `Store` class now its named `Store.act`, removed the standalone `scope.dart` file.
- Removed redundant `ref.get` methods (use `store.get(ref)` instead).

## 0.2.0

- Added error handling method `attempt` and `Result<T>` record typedef.
- Added `select` method to the store to react only to specific value changes.
- Made `watch` and `select` use reference counting for consitency.
- Made documentation improvements

## 0.1.1

- Minor readme improvements
- Added a guard against circular dependencies in refs and family refs.

## 0.1.0

- Initial version.
