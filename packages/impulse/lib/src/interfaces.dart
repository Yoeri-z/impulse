import 'store.dart';

/// A callback function that notifies when a state change occurs.
typedef Listener = void Function();

/// An interface for objects that require manual resource cleanup.
abstract class Disposable {
  /// Releases any resources held by this object.
  void dispose();
}

/// An interface for objects that can be listened to for state changes.
abstract class ImpulseListenable {
  /// Registers a [listener] to be called when the state changes.
  void addListener(Listener listener);

  /// Unregisters a previously registered [listener].
  void removeListener(Listener listener);
}

/// An adapter that defines how to bind and dispose of specific object types within the store.
abstract class ReactivityAdapter {
  /// Called when a value is first retrieved from the store.
  /// Returns an optional unbind function to be called when the value is disposed.
  void Function()? onBind(dynamic value, void Function() notify);

  /// Called when a value is removed from the store to handle cleanup.
  void onDispose(Store store, dynamic value);
}
