import 'package:flutter/material.dart';
import 'package:impulse/impulse.dart';

import 'context_extensions.dart';

/// binds itself to [ref] and fires [builder] when it notifies
class Binder<T> extends StatelessWidget {
  /// Constructs a [Binder]
  const Binder({super.key, required this.ref, required this.builder});

  /// The reference this [Binder] will bind to
  final ImpulseReference<T> ref;

  /// The builder that will run when [ref] of current store notifies.
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    final value = context.use(ref);

    return builder(context, value);
  }
}

/// Selects a specific property of a reference and only runs [builder] if it was different
class Selector<T, R> extends StatefulWidget {
  /// Construct a selector
  const Selector({
    super.key,
    required this.ref,
    required this.select,
    required this.builder,
  });

  /// The reference this [Selector] will bind to
  final ImpulseReference<T> ref;

  /// The property to select
  final R Function(T) select;

  /// The builder that runs when the selected property changes.
  final Widget Function(BuildContext context, R value) builder;

  @override
  State<Selector<T, R>> createState() => _SelectorState<T, R>();
}

class _SelectorState<T, R> extends State<Selector<T, R>> {
  R? value;

  Widget? _cache;

  Widget _buildCachedWidget(BuildContext context) {
    return widget.builder(context, value as R);
  }

  @override
  Widget build(BuildContext context) {
    final obj = context.use(widget.ref);

    final newValue = widget.select(obj);

    if (_cache == null || newValue != value) {
      value = newValue;
      _cache = _buildCachedWidget(context);
    }

    return _cache!;
  }
}

/// Binds itself to [ref] and calls the appropriate builder whenever the [AsyncState] selected with [selector] changes.
class AsyncSelector<T, R> extends StatelessWidget {
  /// Binds itself to [ref] and calls the appropriate builder whenever the [AsyncState] selected with [selector] changes.
  const AsyncSelector({
    super.key,
    required this.ref,
    required this.selector,
    required this.dataBuilder,
    required this.loadingBuilder,
    required this.errorBuilder,
  });

  /// The reference this [AsyncSelector] will bind to
  final ImpulseReference<T> ref;

  /// The async state to select
  final AsyncState<R> Function(T) selector;

  /// The builder that runs when the state has data [R]
  final Widget Function(BuildContext context, R data) dataBuilder;

  /// The builder that runs when the state is loading.
  final Widget Function(BuildContext context, R? previousValue) loadingBuilder;

  /// The builder that runs when the state contains an error
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
    R? previousValue,
  )
  errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Selector(
      ref: ref,
      select: selector,
      builder: (context, state) {
        return switch (state) {
          AsyncLoading(:final previousValue) => loadingBuilder(
            context,
            previousValue,
          ),
          AsyncData(:final value) => dataBuilder(context, value),
          AsyncFailure(:final error, :final stackTrace, :final previousValue) =>
            errorBuilder(context, error, stackTrace, previousValue),
        };
      },
    );
  }
}

/// Builder to safely build based on an [AsyncStateListenable] like [FutureNotifier] or [StreamNotifier].
class AsyncBuilder<T> extends StatefulWidget {
  /// Builder to safely build based on an [AsyncStateListenable] like [FutureNotifier] or [StreamNotifier].
  const AsyncBuilder({
    super.key,
    required this.notifier,
    required this.dataBuilder,
    required this.loadingBuilder,
    required this.errorBuilder,
  });

  /// The object containing the async state
  final AsyncStateListenable<T> notifier;

  /// The builder that runs when the state has data [T]
  final Widget Function(BuildContext context, T data) dataBuilder;

  /// The builder that runs when the state is loading.
  final Widget Function(BuildContext context, T? previousValue) loadingBuilder;

  /// The builder that runs when the state contains an error
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
    T? previousValue,
  )
  errorBuilder;

  @override
  State<AsyncBuilder<T>> createState() => _AsyncBuilderState<T>();
}

class _AsyncBuilderState<T> extends State<AsyncBuilder<T>> {
  void _listener() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_listener);
  }

  @override
  void didUpdateWidget(AsyncBuilder<T> oldWidget) {
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_listener);
      widget.notifier.addListener(_listener);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.notifier.state) {
      AsyncLoading(:final previousValue) => widget.loadingBuilder(
        context,
        previousValue,
      ),
      AsyncData(:final value) => widget.dataBuilder(context, value),
      AsyncFailure(:final error, :final stackTrace, :final previousValue) =>
        widget.errorBuilder(context, error, stackTrace, previousValue),
    };
  }
}
