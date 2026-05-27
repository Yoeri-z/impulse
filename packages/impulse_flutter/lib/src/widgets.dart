import 'package:flutter/material.dart';
import 'package:impulse/impulse.dart';

import 'context_extensions.dart';
import 'store_scope.dart';

/// binds a [ref] to itself and fires [builder] when it notifies
class Binder<T> extends StatelessWidget {
  /// Constructs a [Binder]
  const Binder({super.key, required this.ref, required this.builder});

  /// The reference this [Binder] will bind to
  final ImpulseReference<T> ref;

  /// The builder that will run when [ref] of current store notifies.
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    final value = context.bind(ref);

    return builder(context, value);
  }
}

/// Selects a specific property of a reference and only runs [builder] if it was different
class Selector<T, R> extends StatefulWidget {
  /// Construct a selector
  const Selector({
    super.key,
    required this.ref,
    required this.selector,
    required this.builder,
  });

  /// The reference this [Selector] will bind to
  final ImpulseReference<T> ref;

  /// The property to select
  final R Function(T) selector;

  /// The builder that runs when the selected property changes.
  final Widget Function(BuildContext context, R value) builder;

  @override
  State<Selector<T, R>> createState() => _SelectorState<T, R>();
}

class _SelectorState<T, R> extends State<Selector<T, R>> {
  late R _selectedValue;
  VoidCallback? _unsubscribe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unsubscribe?.call();
    _subscribe();
  }

  void _subscribe() {
    final box = StoreScope.box(context, widget.ref, depend: false);

    _selectedValue = widget.selector(box.produce());

    _unsubscribe = StoreScope.of(context).select<T, R>(
      widget.ref,
      widget.selector,
      (newValue) {
        if (mounted) {
          setState(() {
            _selectedValue = newValue;
          });
        }
      },
    );
  }

  @override
  void didUpdateWidget(Selector<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref.key != widget.ref.key) {
      _unsubscribe?.call();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selectedValue);
  }
}

class ResultSelector<T, R> extends StatelessWidget {
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

  final Widget Function(BuildContext context, R value, Err err)?
  valueAndErrorBuilder;

  @override
  Widget build(BuildContext context) {
    return Selector(
      ref: ref,
      selector: selector,
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
