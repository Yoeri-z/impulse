import 'package:flutter/material.dart';
import 'package:impulse_flutter/impulse_flutter.dart';

// 1. Define a reference to a state class (ChangeNotifier is supported natively)
final counterRef = Ref((store) => ValueNotifier(0));

void main() {
  runApp(
    // 2. Wrap your application in a StoreScope
    const StoreScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CounterPage());
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impulse Counter Example')),
      body: Center(
        child: Text(
          // 3. Make the widget depend on state
          // a widget can hold at most one dependency per reference
          // calling this multiple times has (basically) no effect on performance
          'Count: ${context.use(counterRef).value}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // 4. Use .read(context) to read the state without creating a widget dependency
        onPressed: () => context.read(counterRef).value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
