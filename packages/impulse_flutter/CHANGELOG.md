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
