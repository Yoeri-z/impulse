import 'store.dart';
import 'async/async_utils.dart';

/// A callback function that notifies when a state change occurs.
typedef Listener = void Function();

/// An interface for objects that require manual resource cleanup.
abstract interface class Disposable {
  /// Releases any resources held by this object.
  void dispose();
}

/// An interface for objects that can be listened to for state changes.
abstract interface class ImpulseListenable {
  /// Registers a [listener] to be called when the state changes.
  void addListener(Listener listener);

  /// Unregisters a previously registered [listener].
  void removeListener(Listener listener);
}

/// An adapter that defines how to bind and dispose of specific object types within the store.
abstract interface class ReactivityAdapter {
  /// Called when a value is first retrieved from the store.
  /// Returns an optional unbind function to be called when the value is disposed.
  void Function()? onBind(dynamic value, void Function() notify);

  /// Called when a value is removed from the store to handle cleanup.
  void onDispose(Store store, dynamic value);
}

/// An interface for objects that contain a [Result].
abstract interface class ResultContainer<T> implements ImpulseListenable {
  /// The [Result] contained by this object.
  Result<T> get result;
}
