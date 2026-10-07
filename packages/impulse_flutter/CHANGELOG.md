## 0.9.0
- Updated dependency on `impulse` introducing breaking changes.
- Removed the global `$store` because it is considered an anti pattern within flutter, and i found i never actually used it. 
- Fixed a critical bug where new objects instantiated after a `Store` swap in `StoreScope` would not be tracked for disposal.

## 0.7.0
- Updated dependency on `impulse` introducing breaking changes
- Added `AsyncBuilder`, renamed `ResultSelector` to `AsyncSelector`

## 0.6.3
- added `ResultBuilder` widget

## 0.6.2
- updated dependency constraints

## 0.6.1
- updated example and documentation
- bumped version to match version of other packages

## 0.6.0
- Bumped dependency package versions.
- Jumped versions to sync up with the other packages

## 0.4.0
- Made `context.read` use get the `StoreScope` widget instead of depending.
- Renamed named argument `selector` to `select` in `Selector` widget.

## 0.3.1

- Fixed a bug in context.read debug assertion.

## 0.3.0

- Removed ref extensions, use context extensions instead.
- Renamed context extension `bind` to `use`.
- Added an assert to check if an object is left dangling after instantiation through `read`

## 0.2.1

- Added `ResultSelector` widget to select result fields on registered objects.
  allowing you to easily build loading/error states.

## 0.2.0

- Documentation overhaul.
- `impulse` package version bump.
- Renamed `of` to `bind`.
- Renamed `peek` to `read`.
- Added `Selector` widget.
- Added `StoreScope.of` static method to get the `Store` instance.

## 0.1.1

- Minor readme improvements
- `StoreScope` now wont reset the store if it was given as a construction parameter.
- Bumped `impulse` package version number

## 0.1.0

- Initial version.
