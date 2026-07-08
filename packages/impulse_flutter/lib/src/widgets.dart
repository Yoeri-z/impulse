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

/// Binds itsself to [ref] and calls the appropiate builder whenever the result selected with [selector] changes.
class ResultSelector<T, R> extends StatelessWidget {
  /// Binds itsself to [ref] and calls the appropiate builder whenever the result selected with [selector] changes.
  const ResultSelector({
    super.key,
    required this.ref,
    required this.selector,
    required this.nothingBuilder,
    required this.valueBuilder,
    required this.errBuilder,
    this.valueAndErrorBuilder,
  });

  /// The reference this [Selector] will bind to
  final ImpulseReference<T> ref;

  /// The result to select
  final Result<R> Function(T) selector;

  /// The builder that runs when the selected property has value [R]
  final Widget Function(BuildContext context, R value) valueBuilder;

  /// The builder that runs when the selected property is empty.
  final Widget Function(BuildContext context) nothingBuilder;

  /// The builder that runs when the selected property contains [Err]
  final Widget Function(BuildContext context, Err err) errBuilder;

  /// An optional builder that runs whenever the result contains both a value and an error.
  ///
  /// If not supplied the [valueBuilder] will be used.
  final Widget Function(BuildContext context, R value, Err err)?
  valueAndErrorBuilder;

  @override
  Widget build(BuildContext context) {
    return Selector(
      ref: ref,
      select: selector,
      builder: (context, value) {
        return value.map(
          onNothing: () => Builder(builder: nothingBuilder),
          onValue: (value) =>
              Builder(builder: (context) => valueBuilder(context, value)),
          onError: (err) =>
              Builder(builder: (context) => errBuilder(context, err)),
          onValueAndError: valueAndErrorBuilder == null
              ? null
              : (value, err) => Builder(
                  builder: (context) =>
                      valueAndErrorBuilder!(context, value, err),
                ),
        );
      },
    );
  }
}

/// Builder to safely destructure a [ResultContainer] like [Task] or [StreamTask].
class ResultBuilder<T> extends StatefulWidget {
  /// Builder to safely destructure a [ResultContainer] like [Task] or [StreamTask].
  const ResultBuilder({
    super.key,
    required this.container,
    required this.valueBuilder,
    required this.nothingBuilder,
    required this.errBuilder,
    this.valueAndErrorBuilder,
  });

  /// The object containing a result of type [T]
  final ResultContainer<T> container;

  /// The builder that runs when the selected property has value [R]
  final Widget Function(BuildContext context, T value) valueBuilder;

  /// The builder that runs when the selected property is empty.
  final Widget Function(BuildContext context) nothingBuilder;

  /// The builder that runs when the selected property contains [Err]
  final Widget Function(BuildContext context, Err err) errBuilder;

  /// An optional builder that runs whenever the result contains both a value and an error.
  ///
  /// If not supplied the [valueBuilder] will be used.
  final Widget Function(BuildContext context, T value, Err err)?
  valueAndErrorBuilder;

  @override
  State<ResultBuilder<T>> createState() => _ResultBuilderState<T>();
}

class _ResultBuilderState<T> extends State<ResultBuilder<T>> {
  void _listener() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.container.addListener(_listener);
  }

  @override
  void didUpdateWidget(ResultBuilder<T> oldWidget) {
    if (oldWidget.container != widget.container) {
      oldWidget.container.removeListener(_listener);
      widget.container.addListener(_listener);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.container.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.container.result.map(
      onNothing: () => widget.nothingBuilder(context),
      onValue: (value) => widget.valueBuilder(context, value),
      onError: (err) => widget.errBuilder(context, err),
      onValueAndError: widget.valueAndErrorBuilder != null
          ? (value, err) => widget.valueAndErrorBuilder!(context, value, err)
          : null,
    );
  }
}
