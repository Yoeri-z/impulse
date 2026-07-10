## 0.7.0
- Removed most Async utilities after async overhaul in `impulse_flutter`

## 0.6.2
- updated dependency constraints
- Added some getters to the `ResultExtension`

## 0.6.1
- Added [SignalsReactivityDelegate], overrode `$store` and `createStore` from `impulse_flutter`.
  This [SignalsReactivityDelegate] keeps the [FlutterReactivityDelegate] behavior but exempts `signals` from the listener hook.
- Added example

## 0.6.0
- Bumbed version and dependencies to math the other packages.

## 0.5.1
- Made new signal `AsyncOptions` a parameter on `createComputedAsync` (this was forgotten in version `0.4.0`)
- Made `Controller.disposed` a getter instead of a prop

## 0.5.0
- Removed all the onDispose callbacks. Use `signal.onDispose` instead to register callbacks.

## 0.4.0
- Bumped `impulse_flutter` dependency to `0.4.1`
- updated dependencies to latest versions.
- Changed [Controller] implementation to use the new `AsyncOptions` from signals.

## 0.3.0

- Bumped internal dependencies, nothing in this package changed but the changes in the `impulse_flutter` and `impulse` package are breaking.

## 0.2.0

- Made all methods on `Controller`, except for `dispose`, annotated with `@protected`.
- Updated version of package `impulse_flutter` to 0.2.0, this introduces breaking changes.
- Added `MapResult<T>` extension to the `Result<T>` type.

## 0.1.2

- `impulse_signals` accidentally exported itsself instead of `impulse_flutter` (oops)
  this is now fixed.

## 0.1.1

- Minor readme improvements
- Bumped `impulse_flutter` package version number

## 0.1.0

- Initial version.
