import 'package:meta/meta.dart';

import 'interfaces.dart';

/// A base class for objects that implement [ImpulseListenable] and [Disposable].
class ImpulseNotifier implements ImpulseListenable, Disposable {
  // Null slots indicate a listener was removed.
  final List<Listener?> _listeners = [];
  int _count = 0;
  int _notifyDepth = 0;
  bool _disposed = false;

  /// Whether or not this [ImpulseNotifier] is disposed.
  bool get disposed => _disposed;

  @override
  void addListener(Listener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      _count++;
    }
  }

  @override
  void removeListener(Listener listener) {
    for (var i = 0; i < _count; i++) {
      if (_listeners[i] == listener) {
        _listeners[i] = null;
        break;
      }
    }
  }

  /// Notifies all registered listeners of a state change.
  @protected
  @visibleForTesting
  void notify() {
    if (_count == 0) return;

    final int originalCount = _count;

    _notifyDepth++;
    try {
      for (var i = 0; i < originalCount; i++) {
        final listener = _listeners[i];
        if (listener != null) {
          listener();
        }
      }
    } finally {
      _notifyDepth--;
    }

    // Compacting is deferred to the outermost notification so nested
    // notifications cannot shift slots while an outer loop is still running.
    if (_notifyDepth > 0) return;

    _listeners.removeWhere((item) => item == null);
    _count = _listeners.length;
  }

  @override
  void dispose() {
    _listeners.clear();
    _count = 0;
    _disposed = true;
  }
}
