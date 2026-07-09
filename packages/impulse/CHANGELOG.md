## 0.6.4
- Changed `ImpulseNotifier` implementation to higher performance variant (based on flutters implementation)

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
